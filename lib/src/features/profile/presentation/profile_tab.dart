import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../formulation/data/formulation_repository.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.white,
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => _NotLoggedIn(onLogin: () => context.go('/login')),
        data: (user) {
          if (user == null) {
            return _NotLoggedIn(onLogin: () => context.go('/login'));
          }
          return _UltraProfileContent(user: user, ref: ref);
        },
      ),
    );
  }
}

class _UltraProfileContent extends StatelessWidget {
  final User user;
  final WidgetRef ref;

  const _UltraProfileContent({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unlockFeeFuture = ref
        .read(formulationProvider.notifier)
        .getUnlockFee();
    final currencyFormatter = NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Premium Sliver Header
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          stretch: true,
          backgroundColor: AppTheme.primary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Iconsax.setting_2, color: Colors.white),
              onPressed: () {},
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.blurBackground,
            ],
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Background Gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppTheme.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Decorative circles
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Center profile info
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 110,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar with glassmorphism border
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(
                            user.email.isNotEmpty
                                ? user.email[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.email.split('@').first.capitalize(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          user.tier.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Integrated Stats Card at the bottom of SliverAppBar
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: _GlassStatsCard(user: user, isInHeader: true),
                ),
              ],
            ),
          ),
        ),

        // Body Content
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Subscription upgrade CTA for free users
                if (user.tier == 'free' || user.tier == 'pay_as_you_mix')
                  _UpgradeCard(
                    currentTier: user.tier,
                    unlockFeeFuture: unlockFeeFuture,
                    currencyFormatter: currencyFormatter,
                  ),
                if (user.tier == 'free' || user.tier == 'pay_as_you_mix')
                  const SizedBox(height: 16),
                _buildMenuSection(
                  context,
                  title: 'ACCOUNT SETTINGS',
                  items: [
                    _MenuData(
                      icon: Iconsax.user,
                      title: 'Edit Profile',
                      subtitle: 'Name, email, and farm details',
                      onTap: () => _showEditProfileSheet(context, ref),
                    ),
                    _MenuData(
                      icon: Iconsax.wallet,
                      title: 'Wallet & Billing',
                      subtitle: 'Manage your subscription and funds',
                      onTap: () => context.push('/wallet'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildMenuSection(
                  context,
                  title: 'SUPPORT',
                  items: [
                    _MenuData(
                      icon: Iconsax.info_circle,
                      title: 'Help Center',
                      subtitle: 'FAQs and documentation',
                      onTap: () => _showHelpCenter(context),
                    ),
                    _MenuData(
                      icon: Iconsax.message_question,
                      title: 'Contact Support',
                      subtitle: 'Talk to our team 24/7',
                      onTap: () => _contactSupport(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Logout Button
                _PremiumLogoutButton(onTap: () => _handleLogout(context, ref)),

                const SizedBox(height: 40),
                Text(
                  'AquaFeed v1.0.0 (Production)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.grey400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required List<_MenuData> items,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.grey600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: items.map((data) => _UltraMenuItem(data: data)).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      final authService = await ref.read(authServiceProvider.future);
      await authService.logout();
      ref.invalidate(currentUserProvider);
      if (context.mounted) context.go('/login');
    }
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider).value;
    final nameController = TextEditingController(text: user?.name ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 24,
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
              'Edit Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${user?.email ?? ''}',
              style: TextStyle(color: AppTheme.grey600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Call API to update name
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile update coming soon!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help Center',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _HelpItem(
              question: 'How do I create a feed formulation?',
              answer:
                  'Go to the Mix tab, select your feed standard, choose ingredients, and tap Calculate. Free users get a 2kg demo mix.',
            ),
            _HelpItem(
              question: 'How do I unlock a production mix?',
              answer:
                  'Perform a calculation, then tap "Unlock Production Mix". The current fee is set by admin and charged from your wallet per formula.',
            ),
            _HelpItem(
              question: 'How do I top up my wallet?',
              answer:
                  'Go to Profile → Wallet & Billing → Top Up Wallet. We accept Paystack.',
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _contactSupport() async {
    // Open WhatsApp or email
    final uri = Uri.parse(
      'mailto:support@aquafeedpro.com?subject=Support Request',
    );
    // Note: In production, use url_launcher package
    // For now, show a snackbar with contact info
    debugPrint('Contact support: $uri');
  }
}

class _GlassStatsCard extends StatelessWidget {
  final User user;
  final bool isInHeader;

  const _GlassStatsCard({required this.user, this.isInHeader = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isInHeader
            ? Colors.white.withValues(alpha: 0.15)
            : (isDark ? AppTheme.darkSurface : AppTheme.white),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Balance',
            value: '₦${NumberFormat.compact().format(user.walletBalance)}',
            icon: Iconsax.empty_wallet,
            color: Colors.blue,
            isInHeader: isInHeader,
          ),
          _StatItem(
            label: 'Formulas',
            value: user.formulaCount.toString(),
            icon: Iconsax.document_text,
            color: Colors.amber,
            isInHeader: isInHeader,
          ),
          _StatItem(
            label: 'Farms',
            value: user.farmCount.toString(),
            icon: Iconsax.house_2,
            color: AppTheme.primary,
            isInHeader: isInHeader,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isInHeader;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isInHeader,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isInHeader
                ? Colors.white.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isInHeader ? Colors.white : color, size: 16),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isInHeader
                ? Colors.white
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.black),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isInHeader
                ? Colors.white.withValues(alpha: 0.7)
                : AppTheme.grey400,
          ),
        ),
      ],
    );
  }
}

class _UltraMenuItem extends StatelessWidget {
  final _MenuData data;

  const _UltraMenuItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBg : AppTheme.grey100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                data.icon,
                size: 20,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, size: 16, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }
}

class _PremiumLogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumLogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.1)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.logout, color: AppTheme.error, size: 20),
            SizedBox(width: 12),
            Text(
              'Logout Account',
              style: TextStyle(
                color: AppTheme.error,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final String currentTier;
  final Future<double> unlockFeeFuture;
  final NumberFormat currencyFormatter;

  const _UpgradeCard({
    required this.currentTier,
    required this.unlockFeeFuture,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/wallet'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppTheme.primaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Iconsax.medal_star,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Production Ready Mixes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Unlock full weights & instructions',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder<double>(
                  future: unlockFeeFuture,
                  builder: (context, snapshot) {
                    final amount = (snapshot.data ?? 10000).toDouble();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currencyFormatter.format(amount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'per unlocked mix',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  _MenuData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

class _NotLoggedIn extends StatelessWidget {
  final VoidCallback onLogin;

  const _NotLoggedIn({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Iconsax.profile_circle,
              size: 80,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 24),
            Text(
              'Join the AquaFeed community',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to track your farm\'s performance and unlock premium insights.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppTheme.grey600),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Text(
                  'Sign In Now',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class _HelpItem extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(answer, style: TextStyle(color: AppTheme.grey600, fontSize: 13)),
        ],
      ),
    );
  }
}
