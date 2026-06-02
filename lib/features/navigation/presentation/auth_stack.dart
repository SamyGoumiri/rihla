import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rihla/features/auth/presentation/account_confirmed_page.dart';
import 'package:rihla/features/auth/presentation/login_page.dart';
import 'package:rihla/features/auth/presentation/forgot_password_page.dart';
import 'package:rihla/features/auth/presentation/welcome_page.dart';
import 'package:rihla/features/auth/presentation/signup_page.dart';

class AuthStack extends StatefulWidget {
  const AuthStack({
    super.key,
    required this.onContinueAsGuest,
    this.initialRoute = welcomeRoute,
  });

  final FutureOr<void> Function() onContinueAsGuest;

  final String initialRoute;

  static const welcomeRoute = '/welcome';
  static const loginRoute = '/login';
  static const registerRoute = '/register';
  static const forgotPasswordRoute = '/forgot-password';
  static const accountConfirmedRoute = '/account-confirmed';

  @override
  State<AuthStack> createState() => _AuthStackState();
}

class _AuthStackState extends State<AuthStack> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  PageRoute<void> _buildRoute({
    required RouteSettings settings,
    required Widget page,
  }) {
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final incomingOpacity = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
          reverseCurve: const Interval(0.0, 0.45, curve: Curves.easeIn),
        );

        final outgoingOpacity = Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
            reverseCurve: const Interval(0.55, 1.0, curve: Curves.easeIn),
          ),
        );

        final incomingOffset =
            Tween<Offset>(
              begin: const Offset(0.06, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
                reverseCurve: const Interval(
                  0.0,
                  0.45,
                  curve: Curves.easeInCubic,
                ),
              ),
            );

        return AnimatedBuilder(
          animation: Listenable.merge([incomingOpacity, outgoingOpacity]),
          builder: (context, _) {
            final opacity = incomingOpacity.value * outgoingOpacity.value;
            return FadeTransition(
              opacity: AlwaysStoppedAnimation<double>(opacity),
              child: SlideTransition(position: incomingOffset, child: child),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _AuthSharedBackground(),
        Navigator(
          initialRoute: widget.initialRoute,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case AuthStack.welcomeRoute:
                return _buildRoute(
                  settings: settings,
                  page: WelcomePage(
                    onContinueAsGuest: widget.onContinueAsGuest,
                  ),
                );
              case AuthStack.accountConfirmedRoute:
                return _buildRoute(
                  settings: settings,
                  page: const AccountConfirmedPage(),
                );
              case AuthStack.registerRoute:
                return _buildRoute(
                  settings: settings,
                  page: const SignUpPage(),
                );
              case AuthStack.forgotPasswordRoute:
                return _buildRoute(
                  settings: settings,
                  page: ForgotPasswordPage(
                    initialEmail: settings.arguments is String
                        ? settings.arguments! as String
                        : null,
                  ),
                );
              case AuthStack.loginRoute:
              default:
                return _buildRoute(settings: settings, page: const LoginPage());
            }
          },
        ),
      ],
    );
  }
}

class _AuthSharedBackground extends StatelessWidget {
  const _AuthSharedBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/algeria_landing.png', fit: BoxFit.cover),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x380B1A12), Color(0x850B1A12), Color(0xDB000000)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.15,
              colors: [Color(0x22FFFFFF), Color(0x00000000)],
              stops: [0.0, 0.72],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomCenter,
              radius: 1.33,
              colors: [Color(0x00000000), Color(0x99000000)],
              stops: [0.44, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
