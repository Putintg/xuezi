import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuezi/services/cloud.dart';
import 'package:xuezi/srs/srs.dart';
import 'package:xuezi/state/app_state.dart';

/// Мини-Supabase в памяти: регистрация, вход и таблица progress.
class FakeSupabase {
  final users = <String, String>{}; // почта → пароль
  final rows = <String, Map<String, dynamic>>{}; // uid → data
  bool confirmEmail = false;

  http.Client get client => MockClient((r) async {
        final path = r.url.path;
        if (path == '/auth/v1/signup') {
          final b = jsonDecode(r.body) as Map<String, dynamic>;
          if (users.containsKey(b['email'])) {
            return http.Response(jsonEncode({'error_code': 'user_already_exists'}), 422);
          }
          users[b['email'] as String] = b['password'] as String;
          if (confirmEmail) return http.Response(jsonEncode({'id': 'u-${b['email']}'}), 200);
          return _session(b['email'] as String);
        }
        if (path == '/auth/v1/token') {
          final b = jsonDecode(r.body) as Map<String, dynamic>;
          if (r.url.queryParameters['grant_type'] == 'refresh_token') {
            return _session((b['refresh_token'] as String).substring(2));
          }
          if (users[b['email']] != b['password']) {
            return http.Response(jsonEncode({'error_code': 'invalid_credentials'}), 400);
          }
          return _session(b['email'] as String);
        }
        if (path == '/rest/v1/progress') {
          expect(r.headers['Authorization'], startsWith('Bearer at'));
          if (r.method == 'GET') {
            final uid = r.url.queryParameters['user_id']!.substring(3);
            return _json([if (rows[uid] != null) {'data': rows[uid]}], 200);
          }
          final b = jsonDecode(r.body) as Map<String, dynamic>;
          rows[b['user_id'] as String] = b['data'] as Map<String, dynamic>;
          return http.Response('', 201);
        }
        return http.Response('not found', 404);
      });

  static http.Response _json(Object body, int code) => http.Response.bytes(
      utf8.encode(jsonEncode(body)), code,
      headers: {'content-type': 'application/json; charset=utf-8'});

  http.Response _session(String email) => http.Response(
      jsonEncode({
        'access_token': 'at$email',
        'refresh_token': 'rt$email',
        'expires_in': 3600,
        'user': {'id': 'u-$email', 'email': email},
      }),
      200);
}

void main() {
  late FakeSupabase server;
  setUp(() => server = FakeSupabase());

  Future<(AppState, Cloud)> device(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final s = (await tester.runAsync(AppState.load))!;
    final c = Cloud(await SharedPreferences.getInstance(), s,
        client: server.client, url: 'https://x.supabase.co', key: 'anon');
    return (s, c);
  }

  testWidgets('прогресс переезжает на новый телефон через аккаунт', (tester) async {
    final (a, ca) = await device(tester, {'onboarded': true, 'dailyNew': 3});
    final w = a.sessionQueue(DateTime.now()).first;
    await tester.runAsync(() => a.answer(w, Grade.good));
    final r = await tester.runAsync(() => ca.signUp('me@mail.ru', 'secret1'));
    expect(r, SignInResult.ok);
    expect(server.rows['u-me@mail.ru'], isNotNull);

    // «Переустановка»: пустой телефон, вход тем же аккаунтом.
    final (b, cb) = await device(tester, {});
    expect(b.onboarded, isFalse);
    expect(await tester.runAsync(() => cb.signIn('me@mail.ru', 'secret1')), SignInResult.ok);
    expect(b.onboarded, isTrue);
    expect(b.cards.containsKey(w.id), isTrue);
    expect(b.dailyNew, 3);
    expect(cb.email, 'me@mail.ru');
  });

  testWidgets('прогресс и там и там — пользователь выбирает', (tester) async {
    final (a, ca) = await device(tester, {'onboarded': true});
    final q = a.sessionQueue(DateTime.now());
    await tester.runAsync(() => a.answer(q[0], Grade.good));
    await tester.runAsync(() => ca.signUp('me@mail.ru', 'secret1'));

    final (b, cb) = await device(tester, {'onboarded': true});
    await tester.runAsync(() => b.answer(b.sessionQueue(DateTime.now())[3], Grade.good));
    await tester.runAsync(() => b.answer(b.sessionQueue(DateTime.now())[3], Grade.good));
    expect(await tester.runAsync(() => cb.signIn('me@mail.ru', 'secret1')),
        SignInResult.conflict);
    await tester.runAsync(() => cb.resolveConflict(useRemote: true));
    expect(b.cards.length, 1);
    expect(b.cards.containsKey(q[0].id), isTrue);
  });

  testWidgets('понятные ошибки входа', (tester) async {
    final (_, c) = await device(tester, {});
    final err = await tester.runAsync(() async {
      try {
        await c.signIn('no@mail.ru', 'secret1');
        return null;
      } on CloudError catch (e) {
        return e.message;
      }
    });
    expect(err, contains('Неверная'));
    server.confirmEmail = true;
    expect(await tester.runAsync(() => c.signUp('new@mail.ru', 'secret1')),
        SignInResult.confirmEmail);
    expect(c.signedIn, isFalse);
  });

  testWidgets('прогресс хранится по иероглифам, старый формат читается', (tester) async {
    final (a, _) = await device(tester, {'onboarded': true});
    final w = a.sessionQueue(DateTime.now()).first;
    await tester.runAsync(() => a.answer(w, Grade.good));
    final saved = jsonDecode(a.snapshot()['cards'] as String) as Map;
    expect(saved.keys, [w.hanzi]);

    final (b, _) = await device(tester, {
      'onboarded': true,
      'cards': jsonEncode({'${w.id}': (saved[w.hanzi] as Map)}),
    });
    expect(b.cards.containsKey(w.id), isTrue);
  });
}
