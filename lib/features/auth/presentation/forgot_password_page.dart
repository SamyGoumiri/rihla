import 'package:flutter/material.dart';
import 'package:rihla/components/common/input.dart';
import 'package:rihla/core/services/auth_failure.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/features/navigation/presentation/auth_stack.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/typography.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.initialEmail,
    SupabaseAuthService? authService,
    ConnectivityService? connectivity,
    this.sendPasswordResetEmail,
  }) : _authService = authService,
       _connectivity = connectivity;

  final String? initialEmail;
  final SupabaseAuthService? _authService;
  final ConnectivityService? _connectivity;
  final Future<void> Function(String email)? sendPasswordResetEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _horizontalPadding = 24.0;

  final _formKey = GlobalKey<FormState>();
  final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final _emailController = TextEditingController();
  late final SupabaseAuthService _authService =
      widget._authService ?? SupabaseAuthService();
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();

  bool _isLoading = false;
  bool _isSent = false;
  bool _isEmailValid = false;

  void _backToLogin() {
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

  @override
  void initState() {
    super.initState();
    _emailController.text = (widget.initialEmail ?? '').trim();
    _emailController.addListener(_updateEmailValidity);
    _updateEmailValidity();
  }

  void _updateEmailValidity() {
    final isValid = _emailPattern.hasMatch(_emailController.text.trim());
    if (isValid != _isEmailValid && mounted) {
      setState(() {
        _isEmailValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateEmailValidity);
    _emailController.dispose();
    super.dispose();
  }

  Future<bool> _ensureOnline(String message) async {
    bool online;
    try {
      online = await _connectivity.isOnlineNow().timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      online = true;
    }
    if (!online && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return online;
  }

  Future<void> _sendResetEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim();
      final sender = widget.sendPasswordResetEmail;
      if (sender != null) {
        await sender(email);
      } else {
        if (!await _ensureOnline(
          'Vous êtes hors ligne. Reconnectez-vous pour demander un nouveau mot de passe.',
        )) {
          return;
        }
        await _authService.sendPasswordResetEmail(email: email);
      }
      if (!mounted) return;
      setState(() {
        _isSent = true;
      });
    } on AuthFailure catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final palette = RihlaPalette.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    16,
                    _horizontalPadding,
                    16 + mediaQuery.padding.bottom,
                  ),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 44,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: IconButton(
                                    onPressed: _isLoading ? null : _backToLogin,
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(44, 44),
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
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
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
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
                          Text(
                            'Réinitialiser\nle mot de passe',
                            style: AppTypography.title1.copyWith(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Recevez un lien par email pour définir un nouveau mot de passe.',
                            style: AppTypography.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.66),
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
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
                                AppInput(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  hintText: 'Email',
                                  prefixIcon: Icons.alternate_email_rounded,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.username],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  onFieldSubmitted: (_) => _sendResetEmail(),
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.never,
                                  textStyle: AppTypography.body.copyWith(
                                    color: Colors.white.withValues(alpha: 0.96),
                                    fontSize: 15,
                                  ),
                                  hintStyle: AppTypography.body.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 15,
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  enabled: !_isLoading && !_isSent,
                                  fillColor: const Color(0x2E0A1A12),
                                  focusFillColor: const Color(0x4511261A),
                                  borderColor: Colors.white.withValues(
                                    alpha: 0.24,
                                  ),
                                  focusBorderColor: palette.brandPrimary,
                                  iconColor: Colors.white.withValues(
                                    alpha: 0.88,
                                  ),
                                  focusIconColor: palette.brandPrimary,
                                  borderRadius: 14,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Veuillez saisir un email.';
                                    }
                                    if (!_emailPattern.hasMatch(value.trim())) {
                                      return 'Email invalide.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                if (_isSent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x3329B363),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x8039C975),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: Color(0xFF46D17E),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Email envoyé. Vérifiez votre boîte de réception et vos spams.',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.92),
                                                  fontSize: 12.8,
                                                  height: 1.35,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_isSent) const SizedBox(height: 12),
                                FilledButton(
                                  onPressed:
                                      (_isLoading || _isSent || !_isEmailValid)
                                      ? null
                                      : _sendResetEmail,
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
                                        WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.disabled,
                                          )) {
                                            return palette.brandPrimaryDisabled;
                                          }
                                          if (states.contains(
                                            WidgetState.pressed,
                                          )) {
                                            return palette.brandPrimaryPressed;
                                          }
                                          return palette.brandPrimary;
                                        }),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          _isSent
                                              ? 'Email envoyé'
                                              : 'Envoyer le lien de récupération',
                                          style: AppTypography.bodyStrong,
                                        ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _isLoading ? null : _backToLogin,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white.withValues(
                                      alpha: 0.72,
                                    ),
                                    minimumSize: const Size(44, 44),
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                    textStyle: AppTypography.caption.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  child: const Text('Retour à la connexion'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
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
