class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String authRedirectScheme = 'rihla';
  static const String authRedirectHost = 'auth-callback';
  static const String authRedirectUrl =
      '$authRedirectScheme://$authRedirectHost';

  static const String avatarsBucket = 'avatars';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
