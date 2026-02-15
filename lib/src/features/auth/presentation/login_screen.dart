import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/airbnb_toast.dart';
import '../../../core/widgets/custom_button.dart';
import 'auth_controller.dart';

/// Login Screen - Clean, modern design with pill buttons
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      await ref.read(authControllerProvider.notifier).login(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.black;
    final secondaryColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.grey600;

    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        AirbnbToast.showError(context, next.error.toString());
      } else if (!next.isLoading &&
          !next.hasError &&
          previous?.isLoading == true) {
        context.push('/verify-otp', extra: _emailController.text.trim());
      }
    });

    final state = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 1),

                        // Logo/Icon
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Iconsax.drop,
                              color: AppTheme.primary,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Title
                        Text(
                          'Welcome to\nAquaFeed',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Track your fish farm, formulate feed,\nand maximize your profit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: secondaryColor,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email Input
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurface
                                      : AppTheme.grey100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter your email',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? AppTheme.darkGrey
                                          : AppTheme.grey400,
                                    ),
                                    prefixIcon: Icon(
                                      Iconsax.sms,
                                      color: isDark
                                          ? AppTheme.darkGrey
                                          : AppTheme.grey400,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email is required';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Continue Button - Pill style
                              CustomButton.primary(
                                text: 'Continue with Email',
                                onPressed: state.isLoading ? null : _submit,
                                isLoading: state.isLoading,
                                height: 56,
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Footer
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            'By continuing, you agree to our Terms of Service',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.darkGrey
                                  : AppTheme.grey400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
