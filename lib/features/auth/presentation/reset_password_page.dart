import 'package:flutter/material.dart';
import 'package:rihla/core/services/auth_failure.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    SupabaseAuthService? authService,
    ConnectivityService? connectivity,
    this.updatePassword,
  }) : _authService = authService,
       _connectivity = connectivity;

  final SupabaseAuthService? _authService;
  final ConnectivityService? _connectivity;

  final Future<void> Function(String newPassword)? updatePassword;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final SupabaseAuthService _authService =
      widget._authService ?? SupabaseAuthService();
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();

  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 6) {
      setState(() {
        _errorText =
            'Le nouveau mot de passe doit faire 6 caract\u00e8res ou plus.';
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _errorText = 'Les deux mots de passe ne correspondent pas.';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });
    try {
      final hook = widget.updatePassword;
      if (hook != null) {
        await hook(password);
      } else {
        bool online;
        try {
          online = await _connectivity.isOnlineNow().timeout(
            const Duration(seconds: 3),
          );
        } on Object {
          online = true;
        }
        if (!online) {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _errorText =
                'Vous êtes hors ligne. Reconnectez-vous pour mettre à jour votre mot de passe.';
          });
          return;
        }
        await _authService.updatePassword(password);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe mis \u00e0 jour.')),
      );
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = 'Impossible de mettre \u00e0 jour le mot de passe.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau mot de passe')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  Icon(Icons.lock_reset_rounded, color: palette.brandPrimary),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Text(
                      'Choisissez un nouveau mot de passe pour terminer la r\u00e9cup\u00e9ration de votre compte.',
                      style: AppTypography.body.copyWith(
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _confirmController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.x2),
              Text(
                _errorText!,
                style: AppTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x4),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Mettre \u00e0 jour'),
            ),
          ],
        ),
      ),
    );
  }
}
