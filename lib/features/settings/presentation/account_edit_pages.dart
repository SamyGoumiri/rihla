import 'package:flutter/material.dart';
import 'package:rihla/core/services/auth_failure.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

Future<bool> _isOnlineBeforeAuthCall(ConnectivityService connectivity) async {
  try {
    return await connectivity.isOnlineNow().timeout(const Duration(seconds: 3));
  } on Object {
    return true;
  }
}

class _AccountEditScaffold extends StatelessWidget {
  const _AccountEditScaffold({
    required this.title,
    required this.intro,
    required this.icon,
    required this.children,
    required this.ctaLabel,
    required this.onSubmit,
    required this.isSubmitting,
    this.errorText,
  });

  final String title;
  final String intro;
  final IconData icon;
  final List<Widget> children;
  final String ctaLabel;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: AppTypography.title3.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: palette.brandPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: palette.brandPrimary, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        intro,
                        style: AppTypography.body.copyWith(
                          fontSize: 13.6,
                          height: 1.4,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: palette.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
              if (errorText != null) ...<Widget>[
                const SizedBox(height: AppSpacing.x2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        color: colors.onErrorContainer,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: AppTypography.caption.copyWith(
                            fontSize: 12.8,
                            color: colors.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.x4),
              FilledButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(ctaLabel),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: palette.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: AppTypography.button.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({
    required this.label,
    required this.controller,
    this.helper,
    this.obscure = false,
    this.keyboardType,
    this.autofocus = false,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool autofocus;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            autofocus: autofocus,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLength: maxLength,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '',
            ),
            style: AppTypography.body.copyWith(fontSize: 14.4),
          ),
          if (helper != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              helper!,
              style: AppTypography.caption.copyWith(
                fontSize: 11.8,
                color: palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EditDisplayNamePage extends StatefulWidget {
  const EditDisplayNamePage({
    super.key,
    required this.initialDisplayName,
    required this.authService,
    required this.onSaved,
    ConnectivityService? connectivity,
  }) : _connectivity = connectivity;

  final String initialDisplayName;
  final SupabaseAuthService authService;
  final Future<void> Function(String displayName) onSaved;
  final ConnectivityService? _connectivity;

  @override
  State<EditDisplayNamePage> createState() => _EditDisplayNamePageState();
}

class _EditDisplayNamePageState extends State<EditDisplayNamePage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialDisplayName,
  );
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final next = _controller.text.trim();
    if (next.isEmpty) {
      setState(() => _error = 'Le pseudo ne peut pas être vide.');
      return;
    }
    if (next.length < 4) {
      setState(() => _error = 'Le pseudo doit contenir au moins 4 caractères.');
      return;
    }
    if (next.length > 16) {
      setState(
        () => _error = 'Le pseudo doit contenir au maximum 16 caractères.',
      );
      return;
    }
    if (next == widget.initialDisplayName) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    if (!await _isOnlineBeforeAuthCall(_connectivity)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Vous êtes hors ligne. Reconnectez-vous pour modifier votre pseudo.';
      });
      return;
    }
    try {
      await widget.authService.updateDisplayName(next);
      await widget.onSaved(next);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Impossible de mettre à jour le pseudo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountEditScaffold(
      title: 'Pseudo',
      icon: Icons.person_outline_rounded,
      intro:
          'Votre pseudo est visible sur votre profil et accompagne vos avis publics. Choisissez un nom court et facile à retenir.',
      ctaLabel: 'Enregistrer',
      isSubmitting: _busy,
      errorText: _error,
      onSubmit: _submit,
      children: <Widget>[
        _LabelledField(
          label: 'Pseudo',
          controller: _controller,
          autofocus: true,
          maxLength: 16,
          helper: 'Entre 4 et 16 caractères.',
        ),
      ],
    );
  }
}

class EditPasswordPage extends StatefulWidget {
  const EditPasswordPage({
    super.key,
    required this.authService,
    ConnectivityService? connectivity,
  }) : _connectivity = connectivity;

  final SupabaseAuthService authService;
  final ConnectivityService? _connectivity;

  @override
  State<EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      setState(() => _error = 'Le mot de passe est requis.');
      return;
    }
    if (next.length < 6) {
      setState(
        () =>
            _error = 'Le nouveau mot de passe doit faire 6 caractères ou plus.',
      );
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Les deux nouveaux mots de passe diffèrent.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    if (!await _isOnlineBeforeAuthCall(_connectivity)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Vous êtes hors ligne. Reconnectez-vous pour modifier votre mot de passe.';
      });
      return;
    }
    try {
      await widget.authService.reauthenticate(current);
      await widget.authService.updatePassword(next);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Échec de la mise à jour.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountEditScaffold(
      title: 'Mot de passe',
      icon: Icons.lock_outline_rounded,
      intro:
          'Pour des raisons de sécurité, votre mot de passe est demandé avant tout changement.',
      ctaLabel: 'Mettre à jour',
      isSubmitting: _busy,
      errorText: _error,
      onSubmit: _submit,
      children: <Widget>[
        _LabelledField(
          label: 'Mot de passe',
          controller: _currentController,
          obscure: true,
          autofocus: true,
        ),
        const SizedBox(height: 8),
        _LabelledField(
          label: 'Nouveau mot de passe',
          controller: _newController,
          obscure: true,
          helper: '6 caractères minimum.',
        ),
        const SizedBox(height: 8),
        _LabelledField(
          label: 'Confirmer le nouveau mot de passe',
          controller: _confirmController,
          obscure: true,
        ),
      ],
    );
  }
}

class EditEmailPage extends StatefulWidget {
  const EditEmailPage({
    super.key,
    required this.initialEmail,
    required this.authService,
    ConnectivityService? connectivity,
  }) : _connectivity = connectivity;

  final String initialEmail;
  final SupabaseAuthService authService;
  final ConnectivityService? _connectivity;

  @override
  State<EditEmailPage> createState() => _EditEmailPageState();
}

class _EditEmailPageState extends State<EditEmailPage> {
  late final TextEditingController _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newEmail = _emailController.text.trim();
    final password = _passwordController.text;
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      setState(() => _error = 'Adresse email invalide.');
      return;
    }
    if (newEmail == widget.initialEmail) {
      Navigator.of(context).pop(false);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Le mot de passe est requis.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    if (!await _isOnlineBeforeAuthCall(_connectivity)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Vous êtes hors ligne. Reconnectez-vous pour modifier votre email.';
      });
      return;
    }
    try {
      await widget.authService.reauthenticate(password);
      await widget.authService.updateEmail(newEmail);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Échec du changement d\'email.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountEditScaffold(
      title: 'Email',
      icon: Icons.alternate_email_rounded,
      intro:
          'Un email de vérification sera envoyé à la nouvelle adresse. Le changement n\'est effectif qu\'après confirmation par votre client mail.',
      ctaLabel: 'Envoyer la vérification',
      isSubmitting: _busy,
      errorText: _error,
      onSubmit: _submit,
      children: <Widget>[
        _LabelledField(
          label: 'Nouvel email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        const SizedBox(height: 8),
        _LabelledField(
          label: 'Mot de passe',
          controller: _passwordController,
          obscure: true,
        ),
      ],
    );
  }
}
