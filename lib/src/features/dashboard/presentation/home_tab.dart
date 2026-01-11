import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_state.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/widgets/auth_required_view.dart';

/// Home Tab - Dashboard Overview
/// Clean, high-contrast design for outdoor use
/// Large touch targets, clear hierarchy
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // Header for loading state

  // Header for guest/unauthenticated users
  Widget _buildGuestHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(fontSize: 14, color: AppTheme.grey600),
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome! 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
              ),
            ],
          ),
        ),
        // Sign in button instead of avatar
        GestureDetector(
          onTap: () => context.go('/login'),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.login, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Sign in',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Header for authenticated users
  Widget _buildUserHeader(BuildContext context, WidgetRef ref, User user) {
    final userName = user.email.split('@').first.capitalize();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(fontSize: 14, color: AppTheme.grey600),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
              ),
            ],
          ),
        ),
        // Profile avatar with user initial
        GestureDetector(
          onTap: () =>
              ref.read(dashboardTabIndexProvider.notifier).goToProfile(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardRepositoryProvider.notifier).refresh(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          userAsync.when(
            loading: () => const _LoadingPage(),
            error: (err, stack) => _buildGuestContent(context, ref),
            data: (user) => user == null
                ? _buildGuestContent(context, ref)
                : _buildAuthContent(
                    context,
                    ref,
                    user: user,
                    data: dashboardAsync,
                    formatter: formatter,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestContent(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildGuestHeader(context, ref),
          ),
        ),
        const SizedBox(height: 24),
        _buildQuickActions(context, ref, isGuest: true),
        const SizedBox(height: 24),
        // High-visibility Onboarding Banner (Above the fold)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _OnboardingBanner(),
        ),

        const SizedBox(height: 12),

        // Guest-Specific Content: Market & Standards
        _buildPublicResources(context, ref),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: AuthRequiredView(
            featureName: 'Farm Management',
            description:
                'Track ponds, monitor inventory levels, and view health alerts in real-time.',
            icon: Icons.dashboard_customize_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthContent(
    BuildContext context,
    WidgetRef ref, {
    required User user,
    required AsyncValue<DashboardData> data,
    required NumberFormat formatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildUserHeader(context, ref, user),
          ),
        ),
        const SizedBox(height: 24),
        _buildQuickActions(context, ref, isGuest: false),
        const SizedBox(height: 24),

        // Silent Sync: Priority 1: Show data if we have it (even if refreshing)
        if (data.hasValue)
          _buildDashboardContent(context, ref, data.value!, formatter)
        else if (data.isLoading)
          const _LoadingState()
        else if (data.hasError)
          _ErrorState(
            error: data.error.toString(),
            onRetry: () => ref.invalidate(dashboardRepositoryProvider),
          ),
      ],
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    DashboardData data,
    NumberFormat formatter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Grid - 2 Combined Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Farm Card - Batches + Fish
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(dashboardTabIndexProvider.notifier).goToDiary(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              Icons.water_drop_outlined,
                              size: 20,
                              color: AppTheme.grey400,
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppTheme.grey400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.ponds.length.toString(),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.black,
                                    ),
                                  ),
                                  Text(
                                    'Batches',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.grey600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: AppTheme.grey200,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      NumberFormat.compact().format(
                                        data.ponds.fold<int>(
                                          0,
                                          (sum, p) => sum + p.fishCount,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.black,
                                      ),
                                    ),
                                    Text(
                                      'Fish',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Stock Card - Items + Alerts
              Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(dashboardTabIndexProvider.notifier)
                      .goToInventory(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          (data.inventory.lowStockCount > 0 ||
                              data.inventory.expiringSoonCount > 0)
                          ? AppTheme.warning.withValues(alpha: 0.1)
                          : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          (data.inventory.lowStockCount > 0 ||
                              data.inventory.expiringSoonCount > 0)
                          ? Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: AppTheme.grey400,
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppTheme.grey400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.inventory.totalItems.toString(),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.black,
                                    ),
                                  ),
                                  Text(
                                    'Items',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.grey600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: AppTheme.grey200,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (data.inventory.lowStockCount +
                                              data.inventory.expiringSoonCount)
                                          .toString(),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            (data.inventory.lowStockCount > 0 ||
                                                data
                                                        .inventory
                                                        .expiringSoonCount >
                                                    0)
                                            ? AppTheme.warning
                                            : AppTheme.black,
                                      ),
                                    ),
                                    Text(
                                      'Alerts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Profit/Loss Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _FinancialCard(data: data, formatter: formatter),
        ),

        const SizedBox(height: 24),

        // Batches Section
        _SectionHeader(
          title: 'Your Batches',
          actionLabel: data.ponds.isNotEmpty ? 'See all' : null,
          onAction: () =>
              ref.read(dashboardTabIndexProvider.notifier).goToDiary(),
        ),
        const SizedBox(height: 12),
        data.ponds.isEmpty
            ? _EmptyState(
                icon: Icons.water_drop_outlined,
                title: 'No batches yet',
                subtitle: 'Start tracking your fish batches',
                buttonLabel: 'Create Batch',
                onTap: () =>
                    ref.read(dashboardTabIndexProvider.notifier).goToDiary(),
              )
            : SizedBox(
                height: 120,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: data.ponds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _BatchCard(pond: data.ponds[index]),
                ),
              ),

        // Alerts Section
        if (data.inventory.lowStockCount > 0 ||
            data.inventory.expiringSoonCount > 0) ...[
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Alerts'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (data.inventory.lowStockCount > 0)
                  _AlertItem(
                    icon: Icons.inventory_2_outlined,
                    text: '${data.inventory.lowStockCount} items low on stock',
                    type: AlertType.warning,
                    onTap: () => ref
                        .read(dashboardTabIndexProvider.notifier)
                        .goToInventory(),
                  ),
                if (data.inventory.expiringSoonCount > 0)
                  _AlertItem(
                    icon: Icons.schedule,
                    text:
                        '${data.inventory.expiringSoonCount} items expiring soon',
                    type: AlertType.error,
                    onTap: () => ref
                        .read(dashboardTabIndexProvider.notifier)
                        .goToInventory(),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref, {
    required bool isGuest,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.science_outlined,
                  label: 'New Mix',
                  onTap: () => context.push('/quick-formulation'),
                ),
              ),
              if (!isGuest) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.edit_note,
                    label: 'Log Feed',
                    onTap: () => ref
                        .read(dashboardTabIndexProvider.notifier)
                        .goToDiary(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublicResources(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const _SectionHeader(title: 'Market & Standards'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _SectionCard(
                  title: 'Ingredients',
                  subtitle: 'Recent market prices',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => context.push('/formulation?step=0'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SectionCard(
                  title: 'Standards',
                  subtitle: 'AquaFeed Pro benchmarks',
                  icon: Icons.verified_outlined,
                  onTap: () => context.push('/formulation?step=1'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// === WIDGETS ===

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56, // Large touch target
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppTheme.black),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isWarning;
  final VoidCallback? onTap;
  final String? subtitle;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.isWarning = false,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isWarning
              ? AppTheme.warning.withValues(alpha: 0.1)
              : AppTheme.grey100,
          borderRadius: BorderRadius.circular(20),
          border: isWarning
              ? Border.all(color: AppTheme.warning.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isWarning ? AppTheme.warning : AppTheme.grey400,
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: AppTheme.grey400),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isWarning ? AppTheme.warning : AppTheme.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 10, color: AppTheme.grey400),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final DashboardData data;
  final NumberFormat formatter;

  const _FinancialCard({required this.data, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final isProfit = data.financials.profit >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isProfit ? 'Net Profit' : 'Net Loss',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isProfit ? AppTheme.success : AppTheme.error,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${data.financials.profitMargin.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(data.financials.profit.abs()),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatter.format(data.financials.totalRevenue),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatter.format(data.financials.totalExpenses),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final PondSummary pond;

  const _BatchCard({required this.pond});

  @override
  Widget build(BuildContext context) {
    final statusColor = pond.status == 'Healthy'
        ? AppTheme.success
        : pond.status == 'Attention'
        ? AppTheme.warning
        : AppTheme.grey400;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                pond.status,
                style: TextStyle(fontSize: 11, color: AppTheme.grey600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pond.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            pond.species,
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const Spacer(),
          Text(
            '${NumberFormat.compact().format(pond.fishCount)} fish • FCR ${pond.fcr.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: AppTheme.grey400),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.grey400),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onTap, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

enum AlertType { warning, error }

class _AlertItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final AlertType type;
  final VoidCallback onTap;

  const _AlertItem({
    required this.icon,
    required this.text,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = type == AlertType.warning ? AppTheme.warning : AppTheme.error;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: AppTheme.black),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.grey100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 160,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.grey100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _LoadingState(),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.grey400),
          const SizedBox(height: 16),
          Text(
            'Connection Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

// Extension for capitalize
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingBanner extends StatelessWidget {
  const _OnboardingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Go Pro with AquaFeed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save your mixes, track inventory, and optimize farm profits in real-time.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Create Free Account'),
          ),
        ],
      ),
    );
  }
}
