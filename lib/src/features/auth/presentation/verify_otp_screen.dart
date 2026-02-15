import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/airbnb_toast.dart';
import '../../../core/widgets/custom_button.dart';
import 'auth_controller.dart';

/// OTP Verification Screen - Clean, focused design with dark mode
class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _otpController = TextEditingController();

  void _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) return;
    await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(widget.email, otp);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.black;
    final secondaryColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.grey600;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.grey100;

    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        AirbnbToast.showError(context, next.error.toString());
      } else if (!next.isLoading &&
          !next.hasError &&
          previous?.isLoading == true) {
        AirbnbToast.showSuccess(context, 'Verification successful!');
        context.go('/dashboard');
      }
    });

    final state = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Iconsax.arrow_left, size: 20, color: textColor),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Iconsax.sms,
                    color: AppTheme.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Check your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: secondaryColor,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // OTP Input - Large, centered
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 16,
                    color: AppTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '------',
                    hintStyle: TextStyle(
                      color: isDark ? AppTheme.darkGrey : AppTheme.grey400,
                      letterSpacing: 16,
                    ),
                    counterText: '',
                  ),
                  onChanged: (value) {
                    if (value.length == 6) _verify();
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Verify Button - Pill style
              CustomButton.primary(
                text: 'Verify Code',
                onPressed: state.isLoading ? null : _verify,
                isLoading: state.isLoading,
                height: 56,
              ),

              const Spacer(),

              // Resend
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      Text(
                        "Didn't receive the code?",
                        style: TextStyle(fontSize: 14, color: secondaryColor),
                      ),
                      const SizedBox(height: 12),
                      CustomButton.ghost(
                        text: 'Resend Code',
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .login(widget.email),
                        width: 140,
                        height: 44,
                      ),
                    ],
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
