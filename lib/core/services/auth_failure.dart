class AuthFailure implements Exception {
  const AuthFailure({required this.code, required this.message});

  final String code;

  final String message;

  @override
  String toString() => 'AuthFailure($code): $message';
}
