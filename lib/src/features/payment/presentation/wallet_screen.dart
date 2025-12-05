import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/payment_repository.dart';

/// Wallet & Billing Screen
/// Simple pricing: ₦10,000 for full access, 1 free trial formula
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Wallet & Billing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AuthRequiredView(
          featureName: 'Wallet & Billing',
          description: 'Sign in to manage your wallet and subscription.',
          icon: Icons.wallet_outlined,
        ),
        data: (user) {
          if (user == null) {
            return const AuthRequiredView(
              featureName: 'Wallet & Billing',
              description: 'Sign in to manage your wallet and subscription.',
              icon: Icons.wallet_outlined,
            );
          }

          final hasAccess = user.hasFullAccess;
          final usedFreeTrial = user.freeTrialUsed;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Wallet Balance Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Iconsax.wallet, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Wallet Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      formatter.format(user.walletBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showTopUpSheet(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.add, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Top Up Wallet',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Access Status
              _SectionTitle(title: 'ACCESS STATUS'),
              const SizedBox(height: 12),
              _AccessStatusCard(
                hasAccess: hasAccess,
                usedFreeTrial: usedFreeTrial,
              ),
              const SizedBox(height: 24),

              // Pricing Info
              _SectionTitle(title: 'PRICING'),
              const SizedBox(height: 12),

              // Main Access Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryGreen, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Full Access',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PER MIX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₦10,000',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 6, left: 4),
                          child: Text(
                            '/ formula',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.grey600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FeatureRow(text: 'Production weight (Unlimited kg)'),
                    _FeatureRow(text: 'Hidden ingredient ratios revealed'),
                    _FeatureRow(text: 'Real-time cost optimization'),
                    _FeatureRow(text: 'Strategy comparison (Economy/Premium)'),
                    _FeatureRow(text: 'Nutrient compliance checking'),
                    const SizedBox(height: 20),
                    if (!hasAccess)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.push('/formulation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Calculate & Unlock Mix',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    if (hasAccess)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: AppTheme.success),
                            SizedBox(width: 8),
                            Text(
                              'You have full access',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Free Trial Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.info_circle,
                      color: AppTheme.grey600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        usedFreeTrial
                            ? 'You have used your free trial formula'
                            : 'You get 1 free formula to try the system',
                        style: TextStyle(fontSize: 13, color: AppTheme.grey600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  void _showTopUpSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TopUpSheet(),
    );
  }

  // Removed _handleGetAccess as we now use per-formula unlocking
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.grey600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _AccessStatusCard extends StatelessWidget {
  final bool hasAccess;
  final bool usedFreeTrial;

  const _AccessStatusCard({
    required this.hasAccess,
    required this.usedFreeTrial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasAccess
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.grey100,
        borderRadius: BorderRadius.circular(20),
        border: hasAccess
            ? Border.all(color: AppTheme.success.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasAccess
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasAccess ? Iconsax.tick_circle : Iconsax.lock,
              color: hasAccess ? AppTheme.success : AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAccess ? 'Full Access Active' : 'Limited Access',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAccess
                      ? 'Unlimited formulations available'
                      : usedFreeTrial
                      ? 'Pay ₦10,000 for full access'
                      : '1 free trial remaining',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: AppTheme.success),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _TopUpSheet extends ConsumerStatefulWidget {
  const _TopUpSheet();

  @override
  ConsumerState<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<_TopUpSheet> {
  int _selectedAmount = 10000;
  final _amounts = [5000, 10000, 20000];
  bool _isLoading = false;

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      final paymentService = await ref.read(paymentServiceProvider.future);
      final paymentInit = await paymentService.initializeTopUp(_selectedAmount);

      if (!mounted) return;

      // For now, show the authorization URL or handle in-app
      // In production, use flutter_paystack or url_launcher
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment initiated. Reference: ${paymentInit.reference}',
          ),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      // Close sheet and refresh user data
      Navigator.pop(context);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Up Wallet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum ₦10,000 for full access',
            style: TextStyle(color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _amounts.map((amt) {
              final isSelected = _selectedAmount == amt;
              return GestureDetector(
                onTap: () => setState(() => _selectedAmount = amt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.grey100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '₦${NumberFormat.compact().format(amt)}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Pay ₦${NumberFormat.compact().format(_selectedAmount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Powered by Paystack',
              style: TextStyle(fontSize: 11, color: AppTheme.grey400),
            ),
          ),
        ],
      ),
    );
  }
}
