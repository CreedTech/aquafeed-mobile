import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;

  const StepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepDot(index: 0, currentStep: currentStep, label: 'Ingredients'),
          _buildConnector(0),
          _StepDot(index: 1, currentStep: currentStep, label: 'Config'),
          _buildConnector(1),
          _StepDot(index: 2, currentStep: currentStep, label: 'Result'),
        ],
      ),
    );
  }

  Widget _buildConnector(int index) {
    final active = currentStep > index;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryGreen : AppTheme.grey200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final int currentStep;
  final String label;

  const _StepDot({
    required this.index,
    required this.currentStep,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentStep == index;
    final isCompleted = currentStep > index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28, // Reduced from 32
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppTheme.primaryGreen
                : isActive
                ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                : AppTheme.grey100,
            borderRadius: BorderRadius.circular(10), // Squircle
            border: Border.all(
              color: isActive ? AppTheme.primaryGreen : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive
                          ? AppTheme.primaryGreen
                          : AppTheme.grey400,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isActive || isCompleted ? AppTheme.black : AppTheme.grey400,
          ),
        ),
      ],
    );
  }
}
