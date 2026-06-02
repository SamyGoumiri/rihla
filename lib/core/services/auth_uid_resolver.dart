import 'package:supabase_flutter/supabase_flutter.dart';

String? Function()? _testOverride;

void overrideUidForTesting(String? Function()? resolver) {
  _testOverride = resolver;
}

void resetUidOverride() {
  _testOverride = null;
}

String? resolveCurrentUid() {
  final override = _testOverride;
  if (override != null) {
    return override();
  }
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } on Object {
    return null;
  }
}
