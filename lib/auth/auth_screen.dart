import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF6F7FB), Color(0xFFEFF2FF)],
        ),
      ),
      child: SafeArea(
        child: SignInScreen(
          providers: <AuthProvider>[
            EmailAuthProvider(),
          ],
          headerMaxExtent: 120,
          maxWidth: 420,
          headerBuilder: (BuildContext context, BoxConstraints constraints, double? _) {
            final bool compact = constraints.maxHeight < 140;

            return Padding(
              padding: EdgeInsets.fromLTRB(24, compact ? 16 : 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: Colors.white),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'W1 Chatbot',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to continue to your private chat space.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
