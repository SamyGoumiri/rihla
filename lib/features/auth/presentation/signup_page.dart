import 'package:flutter/material.dart';
import 'package:rihla/components/common/input.dart';
import 'package:rihla/core/services/auth_failure.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/pending_email_confirmation_store.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/auth/presentation/email_sent_page.dart';
import 'package:rihla/features/navigation/presentation/auth_stack.dart';
import 'package:rihla/theme/typography.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    SupabaseAuthService? authService,
    ConnectivityService? connectivity,
    this.createUserWithEmail,
  }) : _authService = authService,
       _connectivity = connectivity;

  final SupabaseAuthService? _authService;
  final ConnectivityService? _connectivity;

  final Future<void> Function(
    String email,
    String password,
    String firstName,
    String lastName,
    String pseudo,
  )?
  createUserWithEmail;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  SupabaseAuthService? get _authService => widget._authService;
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();
  static const _horizontalPadding = 24.0;

  final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  bool _isLoading = false;
  bool _isFormValid = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
    _firstNameController.addListener(_updateFormValidity);
    _lastNameController.addListener(_updateFormValidity);
    _pseudoController.addListener(_updateFormValidity);
    _emailController.addListener(_updateFormValidity);
    _passwordController.addListener(_updateFormValidity);
    _confirmPasswordController.addListener(_updateFormValidity);
  }

  void _updateFormValidity() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final pseudo = _pseudoController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    final valid =
        firstName.isNotEmpty &&
        lastName.isNotEmpty &&
        pseudo.length >= 4 &&
        pseudo.length <= 16 &&
        _emailPattern.hasMatch(email) &&
        password.length >= 6 &&
        confirm == password;

    if (valid != _isFormValid && mounted) {
      setState(() {
        _isFormValid = valid;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_updateFormValidity);
    _lastNameController.removeListener(_updateFormValidity);
    _pseudoController.removeListener(_updateFormValidity);
    _emailController.removeListener(_updateFormValidity);
    _passwordController.removeListener(_updateFormValidity);
    _confirmPasswordController.removeListener(_updateFormValidity);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _pseudoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final pseudo = _pseudoController.text.trim();

      final authService = _authService ?? SupabaseAuthService();
      final createUser = widget.createUserWithEmail;
      if (createUser != null) {
        await createUser(email, password, firstName, lastName, pseudo);
      } else {
        if (!await _ensureOnline(
          'Vous êtes hors ligne. Reconnectez-vous pour créer un compte.',
        )) {
          return;
        }
        await authService.createUserWithEmail(
          email: email,
          password: password,
          displayName: pseudo,
          firstName: firstName,
          lastName: lastName,
        );
      }
      if (!mounted) return;

      if (createUser == null && authService.currentUid != null) {
        return;
      }

      await PendingEmailConfirmationStore.write(email);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EmailSentPage(email: email, authService: authService),
        ),
      );
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
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.of(context).pop(),
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
                            'Créer votre compte',
                            textAlign: TextAlign.left,
                            style: AppTypography.title1.copyWith(
                              color: const Color(0xFFFFFFFF),
                              fontSize: 32,
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
                            'Enregistrez vos favoris et synchronisez vos itinéraires.',
                            textAlign: TextAlign.left,
                            maxLines: 2,
                            style: AppTypography.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
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
                                  controller: _firstNameController,
                                  hintText: 'Prénom',
                                  prefixIcon: Icons.person_outline_rounded,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.givenName,
                                  ],
                                  textCapitalization: TextCapitalization.words,
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
                                  enabled: !_isLoading,
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
                                      return 'Veuillez saisir votre prénom.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                AppInput(
                                  controller: _lastNameController,
                                  hintText: 'Nom',
                                  prefixIcon: Icons.badge_outlined,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.familyName,
                                  ],
                                  textCapitalization: TextCapitalization.words,
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
                                  enabled: !_isLoading,
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
                                      return 'Veuillez saisir votre nom.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                AppInput(
                                  controller: _pseudoController,
                                  hintText: 'Pseudo public',
                                  prefixIcon: Icons.alternate_email_rounded,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.nickname],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  maxLength: 16,
                                  showCounter: false,
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
                                  enabled: !_isLoading,
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
                                    final pseudo = value?.trim() ?? '';
                                    if (pseudo.length < 4) {
                                      return 'Minimum 4 caractères.';
                                    }
                                    if (pseudo.length > 16) {
                                      return 'Maximum 16 caractères.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                AppInput(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  hintText: 'Email',
                                  prefixIcon: Icons.alternate_email_rounded,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newUsername,
                                  ],
                                  autocorrect: false,
                                  enableSuggestions: false,
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
                                  enabled: !_isLoading,
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
                                const SizedBox(height: 14),
                                AppInput(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  hintText: 'Mot de passe',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  autocorrect: false,
                                  enableSuggestions: false,
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
                                  enabled: !_isLoading,
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
                                  suffixIcon: IconButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    tooltip: _obscurePassword
                                        ? 'Afficher le mot de passe'
                                        : 'Masquer le mot de passe',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Veuillez saisir un mot de passe.';
                                    }
                                    if (value.length < 6) {
                                      return 'Minimum 6 caractères.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                AppInput(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  hintText: 'Confirmer le mot de passe',
                                  prefixIcon: Icons.verified_user_outlined,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  onFieldSubmitted: (_) => _submit(),
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
                                  enabled: !_isLoading,
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
                                  suffixIcon: IconButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    tooltip: _obscureConfirmPassword
                                        ? 'Afficher le mot de passe'
                                        : 'Masquer le mot de passe',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Veuillez confirmer le mot de passe.';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Les mots de passe ne correspondent pas.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                _PrimarySignUpButton(
                                  isLoading: _isLoading,
                                  isEnabled: _isFormValid,
                                  onPressed: _submit,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.center,
                                  child: TextButton(
                                    onPressed: _isLoading ? null : _backToLogin,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      minimumSize: const Size(44, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                      textStyle: AppTypography.bodyStrong
                                          .copyWith(fontSize: 14),
                                    ),
                                    child: const Text('J\'ai déjà un compte'),
                                  ),
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

class _PrimarySignUpButton extends StatefulWidget {
  const _PrimarySignUpButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isEnabled;
  final Future<void> Function() onPressed;

  @override
  State<_PrimarySignUpButton> createState() => _PrimarySignUpButtonState();
}

class _PrimarySignUpButtonState extends State<_PrimarySignUpButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.isEnabled && !widget.isLoading;
    final palette = RihlaPalette.of(context);

    return Listener(
      onPointerDown: isInteractive
          ? (_) => setState(() {
              _pressed = true;
            })
          : null,
      onPointerUp: (_) => setState(() {
        _pressed = false;
      }),
      onPointerCancel: (_) => setState(() {
        _pressed = false;
      }),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: FilledButton(
          onPressed: isInteractive ? widget.onPressed : null,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            tapTargetSize: MaterialTapTargetSize.padded,
            animationDuration: const Duration(milliseconds: 180),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return palette.brandPrimaryDisabled;
              }
              if (states.contains(WidgetState.pressed)) {
                return palette.brandPrimaryPressed;
              }
              if (states.contains(WidgetState.hovered)) {
                return palette.brandPrimaryOnSoft;
              }
              return palette.brandPrimary;
            }),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.black.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.white.withValues(alpha: 0.05);
              }
              return null;
            }),
            elevation: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return 0;
              if (states.contains(WidgetState.pressed)) return 2;
              return 5;
            }),
            shadowColor: const WidgetStatePropertyAll(Color(0x3326372D)),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Créer mon compte', style: AppTypography.bodyStrong),
        ),
      ),
    );
  }
}
