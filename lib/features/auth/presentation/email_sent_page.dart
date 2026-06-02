import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rihla/core/services/auth_failure.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/navigation/presentation/auth_stack.dart';
import 'package:rihla/theme/typography.dart';

class EmailSentPage extends StatefulWidget {
  const EmailSentPage({
    super.key,
    required this.email,
    SupabaseAuthService? authService,
    this.resendConfirmationEmail,
    this.resendCooldown = const Duration(seconds: 60),
  }) : _authService = authService;

  final String email;
  final SupabaseAuthService? _authService;

  final Future<void> Function(String email)? resendConfirmationEmail;

  final Duration resendCooldown;

  @override
  State<EmailSentPage> createState() => _EmailSentPageState();
}

class _EmailSentPageState extends State<EmailSentPage> {
  static const _horizontalPadding = 24.0;

  late final SupabaseAuthService _authService =
      widget._authService ?? SupabaseAuthService();

  bool _isResending = false;
  String? _infoText;
  String? _errorText;

  int _resendCountdownSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();

    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _goToLogin() {
    final navigator = Navigator.of(context);
    var foundLogin = false;

    navigator.popUntil((route) {
      if (route.settings.name == AuthStack.loginRoute) {
        foundLogin = true;
        return true;
      }
      return route.isFirst;
    });

    if (!foundLogin) {
      navigator.pushReplacementNamed(AuthStack.loginRoute);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdownSeconds = widget.resendCooldown.inSeconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendCountdownSeconds = 0;
        });
      } else {
        setState(() {
          _resendCountdownSeconds -= 1;
        });
      }
    });
  }

  Future<void> _resend() async {
    if (_resendCountdownSeconds > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _infoText = null;
      _errorText = null;
    });
    try {
      final hook = widget.resendConfirmationEmail;
      if (hook != null) {
        await hook(widget.email);
      } else {
        await _authService.resendSignupConfirmationEmail(email: widget.email);
      }
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _infoText = 'Email de confirmation renvoyé.';
      });
      _startResendCooldown();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorText = 'Impossible de renvoyer l\'email. Réessayez plus tard.';
      });
    }
  }

  String _resendLabel() {
    if (_isResending) return 'Envoi…';
    if (_resendCountdownSeconds > 0) {
      return 'Renvoyer l\'email dans ${_resendCountdownSeconds}s';
    }
    return 'Je n\'ai pas reçu l\'email';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final palette = RihlaPalette.of(context);
    final canResend = _resendCountdownSeconds == 0 && !_isResending;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    16,
                    _horizontalPadding,
                    16 + mediaQuery.padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(44, 44),
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                                tooltip: 'Retour',
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Text(
                                'RIHLA',
                                style: AppTypography.title2.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 20,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Vérifiez vos emails',
                        style: AppTypography.title1.copyWith(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          shadows: const [
                            Shadow(
                              blurRadius: 10,
                              offset: Offset(0, 2),
                              color: Color(0x4D000000),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Un email de confirmation vient d\'être envoyé à :',
                        style: AppTypography.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        style: AppTypography.bodyStrong.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 0.9,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x30000000),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _InstructionRow(
                              icon: Icons.touch_app_outlined,
                              text:
                                  'Ouvrez cet email et cliquez sur le lien de '
                                  'confirmation pour activer votre compte.',
                            ),
                            const SizedBox(height: 14),
                            const _InstructionRow(
                              icon: Icons.schedule_rounded,
                              text:
                                  'Le lien de confirmation est valable 1 heure. '
                                  'Passé ce délai, renvoyez-en un nouveau.',
                            ),
                            const SizedBox(height: 14),
                            const _InstructionRow(
                              icon: Icons.folder_outlined,
                              text:
                                  'Pensez à vérifier votre dossier courriers '
                                  'indésirables (spam).',
                            ),
                            if (_infoText != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _infoText!,
                                style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF46D17E),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (_errorText != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorText!,
                                style: AppTypography.caption.copyWith(
                                  color: const Color(0xFFFF8A80),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _goToLogin,
                              style: ButtonStyle(
                                minimumSize: const WidgetStatePropertyAll(
                                  Size.fromHeight(52),
                                ),
                                tapTargetSize: MaterialTapTargetSize.padded,
                                shape: WidgetStatePropertyAll(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                backgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        WidgetState.pressed,
                                      )) {
                                        return palette.brandPrimaryPressed;
                                      }
                                      return palette.brandPrimary;
                                    }),
                                foregroundColor: const WidgetStatePropertyAll(
                                  Colors.white,
                                ),
                              ),
                              child: Text(
                                'Aller à la connexion',
                                style: AppTypography.bodyStrong,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: canResend ? _resend : null,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withValues(
                                  alpha: 0.82,
                                ),
                                disabledForegroundColor: Colors.white
                                    .withValues(alpha: 0.45),
                                minimumSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.padded,
                                textStyle: AppTypography.caption.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text(_resendLabel()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.brandPrimary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13.6,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
