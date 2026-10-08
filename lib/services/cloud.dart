import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import 'cloud_config.dart';

/// Ошибка аккаунта с понятным пользователю текстом.
class CloudError implements Exception {
  CloudError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Чем закончился вход.
enum SignInResult {
  /// Вошли, прогресс уже совпадает или пуст с обеих сторон.
  ok,

  /// Нужно подтвердить почту по письму.
  confirmEmail,

  /// И в аккаунте, и на телефоне есть прогресс: пользователь выбирает.
  conflict,
}

/// Аккаунт и синхронизация прогресса через Supabase (REST, без нативных
/// библиотек). Весь прогресс — снимок настроек приложения в одной строке
/// таблицы `progress`.
class Cloud extends ChangeNotifier {
  Cloud(this._prefs, this.state, {http.Client? client, String? url, String? key})
      : _http = client ?? http.Client(),
        _url = (url ?? CloudConfig.url).replaceAll(RegExp(r'/+$'), ''),
        _key = key ?? CloudConfig.anonKey;

  /// Единственный экземпляр приложения.
  static Cloud? instance;

  final SharedPreferences _prefs;
  final AppState state;
  final http.Client _http;
  final String _url, _key;
  Timer? _debounce;
  bool _applying = false;
  bool busy = false;
  String? lastError;

  /// Удалённая копия, ожидающая решения пользователя при конфликте.
  Map<String, dynamic>? pendingRemote;

  bool get configured => _url.isNotEmpty && _key.isNotEmpty;
  String? get email => _prefs.getString('cloud.email');
  bool get signedIn => _prefs.getString('cloud.refresh') != null;
  DateTime? get lastSync {
    final s = _prefs.getString('cloud.lastSync');
    return s == null ? null : DateTime.tryParse(s);
  }

  String? get _uid => _prefs.getString('cloud.uid');

  /// Подписка на изменения прогресса: выгрузка через пару секунд после
  /// последнего изменения.
  void start() {
    state.addListener(_onLocalChange);
    if (signedIn) unawaited(pull());
  }

  void _onLocalChange() {
    if (_applying || !signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => unawaited(push()));
  }

  /// Выгрузить сразу (например, при сворачивании приложения).
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      await push();
    }
  }

  // ---------- Вход ----------

  Map<String, String> get _headers => {
        'apikey': _key,
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> _auth(String path, Map<String, dynamic> body) async {
    final http.Response r;
    try {
      r = await _http
          .post(Uri.parse('$_url/auth/v1/$path'),
              headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw CloudError('Нет связи с сервером. Проверьте интернет.');
    }
    final j = r.bodyBytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode >= 400) throw CloudError(_authMessage(j));
    return j;
  }

  static String _authMessage(Map<String, dynamic> j) {
    final code = '${j['error_code'] ?? j['code'] ?? ''}';
    final msg = '${j['msg'] ?? j['error_description'] ?? j['message'] ?? ''}';
    if (code == 'invalid_credentials' || msg.contains('Invalid login')) {
      return 'Неверная почта или пароль.';
    }
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return 'Почта ещё не подтверждена. Откройте письмо и нажмите ссылку.';
    }
    if (code == 'user_already_exists' || msg.contains('already registered')) {
      return 'Такой аккаунт уже есть. Войдите с этой почтой.';
    }
    if (code == 'weak_password' || msg.contains('Password should')) {
      return 'Пароль слишком короткий: нужно минимум 6 символов.';
    }
    if (code == 'validation_failed' || msg.contains('invalid format')) {
      return 'Проверьте адрес почты.';
    }
    if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit') {
      return 'Слишком много попыток. Подождите минуту.';
    }
    return msg.isEmpty ? 'Не получилось. Попробуйте ещё раз.' : msg;
  }

  Future<void> _saveSession(Map<String, dynamic> j) async {
    final user = j['user'] as Map<String, dynamic>?;
    await _prefs.setString('cloud.access', j['access_token'] as String);
    await _prefs.setString('cloud.refresh', j['refresh_token'] as String);
    final exp = DateTime.now().add(Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 3600));
    await _prefs.setString('cloud.expires', exp.toIso8601String());
    if (user != null) {
      await _prefs.setString('cloud.uid', user['id'] as String);
      if (user['email'] != null) await _prefs.setString('cloud.email', user['email'] as String);
    }
  }

  Future<SignInResult> signUp(String email, String password) => _run(() async {
        final j = await _auth('signup', {'email': email.trim(), 'password': password});
        if (j['access_token'] == null) return SignInResult.confirmEmail;
        await _saveSession(j);
        return _afterSignIn();
      });

  Future<SignInResult> signIn(String email, String password) => _run(() async {
        final j = await _auth('token?grant_type=password',
            {'email': email.trim(), 'password': password});
        await _saveSession(j);
        return _afterSignIn();
      });

  Future<void> resetPassword(String email) =>
      _run(() => _auth('recover', {'email': email.trim()}));

  Future<void> signOut() async {
    await flush();
    for (final k in _prefs.getKeys().where((k) => k.startsWith('cloud.')).toList()) {
      await _prefs.remove(k);
    }
    pendingRemote = null;
    notifyListeners();
  }

  /// После входа: сравнить прогресс в аккаунте и на телефоне.
  Future<SignInResult> _afterSignIn() async {
    final remote = await _fetch();
    final localP = state.progress;
    if (remote == null) {
      await push();
      return SignInResult.ok;
    }
    final remoteP = AppState.progressOf(remote);
    if (localP == 0 || remoteP == localP) {
      await _apply(remote);
      return SignInResult.ok;
    }
    if (remoteP == 0) {
      await push();
      return SignInResult.ok;
    }
    pendingRemote = remote;
    return SignInResult.conflict;
  }

  /// Решение конфликта: взять прогресс из аккаунта или с этого телефона.
  Future<void> resolveConflict({required bool useRemote}) => _run(() async {
        final r = pendingRemote;
        pendingRemote = null;
        if (useRemote && r != null) {
          await _apply(r);
        } else {
          await push();
        }
      });

  // ---------- Данные ----------

  Future<String> _token() async {
    final exp = DateTime.tryParse(_prefs.getString('cloud.expires') ?? '');
    final access = _prefs.getString('cloud.access');
    if (access != null && exp != null && exp.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return access;
    }
    final refresh = _prefs.getString('cloud.refresh');
    if (refresh == null) throw CloudError('Войдите в аккаунт.');
    final j = await _auth('token?grant_type=refresh_token', {'refresh_token': refresh});
    await _saveSession(j);
    return j['access_token'] as String;
  }

  Future<Map<String, String>> _authHeaders() async =>
      {..._headers, 'Authorization': 'Bearer ${await _token()}'};

  Future<Map<String, dynamic>?> _fetch() async {
    final r = await _http
        .get(Uri.parse('$_url/rest/v1/progress?user_id=eq.$_uid&select=data'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    if (r.statusCode >= 400) throw CloudError('Не удалось загрузить прогресс (${r.statusCode}).');
    final rows = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    if (rows.isEmpty) return null;
    return (rows.first as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<void> _apply(Map<String, dynamic> remote) async {
    _applying = true;
    try {
      await state.restoreSnapshot(remote);
    } finally {
      _applying = false;
    }
    await _markSynced();
  }

  Future<void> _markSynced() async {
    await _prefs.setString('cloud.lastSync', DateTime.now().toIso8601String());
    lastError = null;
    notifyListeners();
  }

  /// Отправить прогресс с телефона в аккаунт.
  Future<void> push() async {
    if (!signedIn || !configured) return;
    try {
      final r = await _http
          .post(Uri.parse('$_url/rest/v1/progress'),
              headers: {
                ...await _authHeaders(),
                'Prefer': 'resolution=merge-duplicates,return=minimal',
              },
              body: jsonEncode({
                'user_id': _uid,
                'data': state.snapshot(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 400) throw CloudError('Не удалось сохранить прогресс (${r.statusCode}).');
      await _markSynced();
    } catch (e) {
      lastError = e is CloudError ? e.message : 'Нет связи с сервером.';
      notifyListeners();
    }
  }

  /// Загрузить прогресс из аккаунта, если там больше, чем на телефоне
  /// (например, занимались на другом устройстве).
  Future<void> pull() async {
    if (!signedIn || !configured) return;
    try {
      final remote = await _fetch();
      if (remote == null) {
        await push();
      } else if (AppState.progressOf(remote) > state.progress) {
        await _apply(remote);
      } else {
        await push();
      }
    } catch (e) {
      lastError = e is CloudError ? e.message : 'Нет связи с сервером.';
      notifyListeners();
    }
  }

  Future<T> _run<T>(Future<T> Function() f) async {
    busy = true;
    notifyListeners();
    try {
      return await f();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
