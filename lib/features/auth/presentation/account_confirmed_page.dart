import 'package:flutter/material.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/navigation/presentation/auth_stack.dart';
import 'package:rihla/theme/typography.dart';

class AccountConfirmedPage extends StatelessWidget {
  const AccountConfirmedPage({super.key, this.onGoToLogin});

  final VoidCallback? onGoToLogin;

  void _goToLogin(BuildContext context) {
    final override = onGoToLogin;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(context).pushNamed(AuthStack.loginRoute);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final palette = RihlaPalette.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            16 + mediaQuery.padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.topRight,
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
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF46D17E),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Compte créé\navec succès',
                textAlign: TextAlign.center,
                style: AppTypography.title1.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                  shadows: const [
                    Shadow(
                      blurRadius: 10,
                      offset: Offset(0, 2),
                      color: Color(0x4D000000),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Votre adresse email est confirmée. Connectez-vous pour '
                'commencer à explorer l\'Algérie avec Rihla.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _goToLogin(context),
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
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return palette.brandPrimaryPressed;
                    }
                    return palette.brandPrimary;
                  }),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                ),
                child: Text('Se connecter', style: AppTypography.bodyStrong),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
