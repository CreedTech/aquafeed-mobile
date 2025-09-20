import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'custom_button.dart';

/// AuthRequiredView - A beautiful, premium-looking screen for guest users
/// Prompts them to login to access protected features.
class AuthRequiredView extends StatelessWidget {
  final String featureName;
  final String description;
  final IconData icon;

  const AuthRequiredView({
    super.key,
    required this.featureName,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with soft glow or background
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 32),

            // Text Content
            Text(
              featureName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.white : AppTheme.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppTheme.grey400 : AppTheme.grey600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Action Buttons
            CustomButton.primary(
              text: 'Sign in to Continue',
              onPressed: () => context.push('/login'),
            ),
            const SizedBox(height: 16),
            CustomButton.outlined(
              text: 'Create Account',
              onPressed: () =>
                  context.push('/login'), // Both go to login/otp flow for now
            ),

            // Subtle "Browse as Guest" hint or footer
            const SizedBox(height: 32),
            Text(
              'Join thousands of farmers optimizing their yields with AquaFeed Pro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.grey600.withValues(alpha: 0.5)
                    : AppTheme.grey400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
