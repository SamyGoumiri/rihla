import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rihla/app/app.dart';
import 'package:rihla/core/config/supabase_config.dart';
import 'package:rihla/core/database/local_database.dart';
import 'package:rihla/core/services/guest_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } else {
    developer.log(
      'Supabase n\'est pas configuré (SUPABASE_URL / SUPABASE_ANON_KEY '
      'manquants). Les fonctions backend Supabase seront indisponibles. '
      'Passez les valeurs via --dart-define au build.',
      name: 'main',
      level: 900,
    );
  }

  await LocalDatabase.instance.open();

  await GuestSessionService.initialize();
  runApp(const PfeApp());
}
