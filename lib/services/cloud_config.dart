/// Адрес и публичный ключ проекта Supabase для аккаунтов.
/// Публичный (anon) ключ можно хранить в коде: доступ к данным
/// ограничен правилами в базе — каждый видит только свой прогресс.
/// Можно также передать при сборке:
/// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://idwovxdziabtipzjcurb.supabase.co');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_R5tmXoCflrRI5sA_LO57MA_82tgkqqu');
}
