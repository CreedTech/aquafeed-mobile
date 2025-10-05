import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../data/dashboard_state.dart';
import 'home_tab.dart';
import '../../diary/presentation/diary_tab.dart';
import '../../inventory/presentation/inventory_tab.dart';
import '../../financials/presentation/financials_tab.dart';
import '../../profile/presentation/profile_tab.dart';

/// Main Dashboard - Airbnb-style bottom navigation with Mix as primary action
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const List<Widget> _tabs = [
    HomeTab(),
    DiaryTab(),
    InventoryTab(),
    FinancialsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(dashboardTabIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.white;
    final borderColor = isDark ? AppTheme.darkGrey : AppTheme.grey200;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: selectedIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                _NavItem(
                  icon: Iconsax.home_1,
                  activeIcon: Iconsax.home,
                  label: 'Home',
                  isSelected: selectedIndex == 0,
                  onTap: () =>
                      ref.read(dashboardTabIndexProvider.notifier).setTab(0),
                ),
                _NavItem(
                  icon: Iconsax.note_1,
                  activeIcon: Iconsax.note,
                  label: 'Diary',
                  isSelected: selectedIndex == 1,
                  onTap: () =>
                      ref.read(dashboardTabIndexProvider.notifier).setTab(1),
                ),
                // Center Mix Button - Primary Action
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/formulation'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Iconsax.blend,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mix',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _NavItem(
                  icon: Iconsax.wallet_1,
                  activeIcon: Iconsax.wallet,
                  label: 'Finance',
                  isSelected: selectedIndex == 3,
                  onTap: () =>
                      ref.read(dashboardTabIndexProvider.notifier).setTab(3),
                ),
                _NavItem(
                  icon: Iconsax.profile_circle,
                  activeIcon: Iconsax.profile_circle,
                  label: 'Profile',
                  isSelected: selectedIndex == 4,
                  onTap: () =>
                      ref.read(dashboardTabIndexProvider.notifier).setTab(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation Item - Large touch target, premium IconSax icons
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppTheme.primary;
    final inactiveColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.grey400;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 24,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
