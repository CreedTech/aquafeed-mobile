import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom Button - Airbnb-style with pill radius and optional icons
/// Supports both filled and outlined variants
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final double? height;
  final double? width;
  final EdgeInsets? margin;
  final bool isOutlined;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.leftIcon,
    this.rightIcon,
    this.height,
    this.width,
    this.margin,
    this.isOutlined = false,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.borderRadius = 55, // Pill-like by default
  });

  /// Filled primary button
  factory CustomButton.primary({
    required String text,
    VoidCallback? onPressed,
    Widget? leftIcon,
    Widget? rightIcon,
    double? height,
    double? width,
    EdgeInsets? margin,
    bool isLoading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      height: height,
      width: width,
      margin: margin,
      isLoading: isLoading,
      backgroundColor: AppTheme.primary,
      textColor: Colors.white,
    );
  }

  /// Outlined button
  factory CustomButton.outlined({
    required String text,
    VoidCallback? onPressed,
    Widget? leftIcon,
    Widget? rightIcon,
    double? height,
    double? width,
    EdgeInsets? margin,
    bool isLoading = false,
    Color? borderColor,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      height: height,
      width: width,
      margin: margin,
      isLoading: isLoading,
      isOutlined: true,
      borderColor: borderColor ?? AppTheme.black,
      textColor: AppTheme.black,
    );
  }

  /// Secondary/Ghost button
  factory CustomButton.ghost({
    required String text,
    VoidCallback? onPressed,
    Widget? leftIcon,
    Widget? rightIcon,
    double? height,
    double? width,
    EdgeInsets? margin,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      height: height,
      width: width,
      margin: margin,
      backgroundColor: AppTheme.grey100,
      textColor: AppTheme.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBgColor = isOutlined
        ? Colors.transparent
        : (backgroundColor ?? AppTheme.primary);

    final effectiveTextColor =
        textColor ??
        (isOutlined
            ? (isDark ? AppTheme.white : AppTheme.black)
            : Colors.white);

    final effectiveBorderColor =
        borderColor ?? (isDark ? AppTheme.darkGrey : AppTheme.black);

    return Container(
      height: height ?? 56,
      width: width ?? double.infinity,
      margin: margin,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: effectiveBgColor,
          foregroundColor: effectiveTextColor,
          elevation: 0,
          disabledBackgroundColor: effectiveBgColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            side: isOutlined
                ? BorderSide(color: effectiveBorderColor, width: 1.5)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: effectiveTextColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leftIcon != null) ...[
                    leftIcon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: effectiveTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (rightIcon != null) ...[
                    const SizedBox(width: 8),
                    rightIcon!,
                  ],
                ],
              ),
      ),
    );
  }
}
