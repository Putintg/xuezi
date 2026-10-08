import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cloud.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// Вход в аккаунт, синхронизация и резервная копия.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.state, this.cloud});
  final AppState state;
  final Cloud? cloud;

  @override
  Widget build(BuildContext context) {
    final c = cloud;
    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунт')),
      body: c == null || !c.configured
          ? ListView(children: [_BackupSection(state: state)])
          : ListenableBuilder(
              listenable: c,
              builder: (context, _) => ListView(
                children: [
                  if (c.signedIn) _SignedIn(cloud: c) else _SignInForm(cloud: c),
                  const Divider(height: 32),
                  _BackupSection(state: state),
                ],
              ),
            ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.cloud});
  final Cloud cloud;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = cloud.lastSync;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const CircleAvatar(
              backgroundColor: Palette.jade,
              foregroundColor: Colors.white,
              child: Icon(Icons.cloud_done_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cloud.email ?? 'Аккаунт', style: t.titleMedium),
                  Text(
                    cloud.lastError ??
                        (last == null
                            ? 'Прогресс сохраняется в аккаунте'
                            : 'Сохранено ${_time(last)}'),
                    style: t.bodySmall?.copyWith(
                        color: cloud.lastError != null ? Palette.cinnabar : null),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            'Прогресс, уроки и настройки сохраняются автоматически. '
            'Войдите с этой почтой на другом телефоне или после '
            'переустановки, и всё вернётся.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: cloud.busy
                ? const SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            label: const Text('Синхронизировать сейчас'),
            onPressed: cloud.busy ? null : cloud.pull,
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Выйти из аккаунта?'),
                  content: const Text(
                      'Прогресс останется и на телефоне, и в аккаунте.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Выйти')),
                  ],
                ),
              );
              if (ok ?? false) await cloud.signOut();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime t) {
    final now = DateTime.now();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return 'сегодня в $hm';
    }
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} в $hm';
  }
}

class _SignInForm extends StatefulWidget {
  const _SignInForm({required this.cloud});
  final Cloud cloud;

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _info = null;
    });
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Введите адрес почты.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Пароль: минимум 6 символов.');
      return;
    }
    try {
      final r = _register
          ? await widget.cloud.signUp(email, _password.text)
          : await widget.cloud.signIn(email, _password.text);
      if (!mounted) return;
      switch (r) {
        case SignInResult.ok:
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Готово, прогресс сохранён в аккаунте')));
        case SignInResult.confirmEmail:
          setState(() {
            _register = false;
            _info = 'Мы отправили письмо на $email. Нажмите ссылку в нём, '
                'затем войдите здесь.';
          });
        case SignInResult.conflict:
          await _askConflict();
      }
    } on CloudError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _askConflict() async {
    final useRemote = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Какой прогресс оставить?'),
        content: const Text(
            'В аккаунте уже есть прогресс, и на этом телефоне тоже. '
            'Выберите, какой оставить. Второй будет заменён.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('С телефона')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Из аккаунта')),
        ],
      ),
    );
    await widget.cloud.resolveConflict(useRemote: useRemote ?? true);
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Сначала введите почту.');
      return;
    }
    try {
      await widget.cloud.resetPassword(email);
      setState(() => _info = 'Письмо для смены пароля отправлено на $email.');
    } on CloudError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final busy = widget.cloud.busy;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_register ? 'Создать аккаунт' : 'Войти', style: t.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Прогресс будет храниться в аккаунте: он не потеряется при '
              'переустановке и перейдёт на новый телефон.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Почта', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hide,
              autofillHints: [
                _register ? AutofillHints.newPassword : AutofillHints.password
              ],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: t.bodyMedium?.copyWith(color: Palette.cinnabar)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              Text(_info!, style: t.bodyMedium?.copyWith(color: Palette.jade)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox.square(
                      dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_register ? 'Создать аккаунт' : 'Войти'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
              child: Text(_register
                  ? 'Уже есть аккаунт? Войти'
                  : 'Нет аккаунта? Создать'),
            ),
            if (!_register)
              TextButton(
                  onPressed: busy ? null : _forgot,
                  child: const Text('Забыли пароль?')),
          ],
        ),
      ),
    );
  }
}

/// Резервная копия без аккаунта: код копируется в буфер обмена.
class _BackupSection extends StatelessWidget {
  const _BackupSection({required this.state});
  final AppState state;

  static const _prefix = 'XUEZI1:';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Резервная копия', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Без аккаунта: скопируйте код и сохраните его, например, в Заметках. '
            'Чтобы восстановить, скопируйте код и нажмите «Восстановить».',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Скопировать'),
                onPressed: () async {
                  final code = _prefix +
                      base64Url.encode(gzip.encode(utf8.encode(jsonEncode(state.snapshot()))));
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Код копии скопирован. Сохраните его в Заметках.')));
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Восстановить'),
                onPressed: () => _restore(context),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final text = (await Clipboard.getData('text/plain'))?.text?.trim() ?? '';
    Map<String, dynamic>? snap;
    if (text.startsWith(_prefix)) {
      try {
        snap = jsonDecode(utf8.decode(gzip.decode(base64Url.decode(text.substring(_prefix.length)))))
            as Map<String, dynamic>;
      } catch (_) {}
    }
    if (!context.mounted) return;
    if (snap == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('В буфере обмена нет кода копии. Скопируйте его целиком.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Восстановить из копии?'),
        content: const Text('Текущий прогресс на телефоне будет заменён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Восстановить')),
        ],
      ),
    );
    if (ok ?? false) {
      await state.restoreSnapshot(snap);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Прогресс восстановлен')));
      }
    }
  }
}
