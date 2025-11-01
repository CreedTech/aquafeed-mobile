import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Simple loading indicator
class AuraLoader extends StatelessWidget {
  const AuraLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Calculating...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey600,
          ),
        ),
      ],
    );
  }
}
