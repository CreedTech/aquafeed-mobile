import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/airbnb_toast.dart';
import '../../../core/widgets/custom_button.dart';
import '../data/financials_repository.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../auth/data/auth_repository.dart';

/// Financials Tab - Expenses and Revenue tracking
class FinancialsTab extends ConsumerStatefulWidget {
  const FinancialsTab({super.key});

  @override
  ConsumerState<FinancialsTab> createState() => _FinancialsTabState();
}

class _FinancialsTabState extends ConsumerState<FinancialsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.white,
      appBar: AppBar(
        title: const Text('Finance'),
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.white,
        surfaceTintColor: Colors.transparent,
        bottom: user != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface2 : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: AppTheme.white,
                      unselectedLabelColor: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.grey600,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Expenses'),
                        Tab(text: 'Revenue'),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (_, __) => const AuthRequiredView(
          featureName: 'Financial Analytics',
          description:
              'Manage your expenses and track revenue to maximize your profit margins.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        data: (user) => user == null
            ? const AuthRequiredView(
                featureName: 'Financial Analytics',
                description:
                    'Manage your expenses and track revenue to maximize your profit margins.',
                icon: Icons.account_balance_wallet_outlined,
              )
            : TabBarView(
                controller: _tabController,
                children: const [_ExpensesView(), _RevenuesView()],
              ),
      ),
      floatingActionButton: user != null
          ? FloatingActionButton(
              onPressed: () => _tabController.index == 0
                  ? _showAddExpenseSheet(context)
                  : _showAddRevenueSheet(context),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'Feed';
    bool isLoading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Expense',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: category,
                    isExpanded: true,
                    items:
                        [
                              'Feed',
                              'Labor',
                              'Equipment',
                              'Transport',
                              'Supplies',
                              'Marketing',
                              'Maintenance',
                              'Utilities',
                              'Fingerlings',
                              'Other',
                            ]
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                    onChanged: (v) => setModalState(() => category = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  hintText: 'What was this for?',
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Amount (₦)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixText: '₦ ',
                ),
              ),
              const SizedBox(height: 16),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 14),
                  ),
                ),

              CustomButton.primary(
                text: 'Save Expense',
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () async {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          setModalState(() => error = 'Enter a valid amount');
                          return;
                        }
                        setModalState(() {
                          isLoading = true;
                          error = null;
                        });

                        try {
                          await ref
                              .read(expensesProvider.notifier)
                              .addExpense(
                                category: category,
                                description: descController.text,
                                amount: amount,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            AirbnbToast.showSuccess(context, 'Expense added');
                          }
                        } catch (e) {
                          setModalState(() {
                            isLoading = false;
                            error = e.toString();
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRevenueSheet(BuildContext context) {
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final buyerController = TextEditingController();
    String type = 'TableSize'; // Default to most common
    bool isLoading = false;
    String? error;

    // Map enum values to display labels
    const typeOptions = {
      'TableSize': 'Table Size Fish',
      'Fingerling': 'Fingerlings',
      'Other': 'Other',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Revenue',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: type,
                    isExpanded: true,
                    items: typeOptions.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => type = v!),
                  ),
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
                          'Quantity (kg)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price/kg (₦)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Buyer (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: buyerController,
                decoration: const InputDecoration(hintText: 'Customer name'),
              ),
              const SizedBox(height: 16),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 14),
                  ),
                ),

              CustomButton.primary(
                text: 'Save Revenue',
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () async {
                        final qty = int.tryParse(quantityController.text);
                        final price = double.tryParse(priceController.text);
                        if (qty == null ||
                            qty <= 0 ||
                            price == null ||
                            price <= 0) {
                          setModalState(
                            () => error = 'Enter valid quantity and price',
                          );
                          return;
                        }
                        setModalState(() {
                          isLoading = true;
                          error = null;
                        });

                        try {
                          await ref
                              .read(revenuesProvider.notifier)
                              .addRevenue(
                                type: type,
                                quantity: qty,
                                pricePerUnit: price,
                                buyer: buyerController.text.isNotEmpty
                                    ? buyerController.text
                                    : null,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            AirbnbToast.showSuccess(context, 'Revenue added');
                          }
                        } catch (e) {
                          setModalState(() {
                            isLoading = false;
                            error = e.toString();
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expenses View
class _ExpensesView extends ConsumerWidget {
  const _ExpensesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d');

    return expensesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (error, _) => _ErrorState(
        error: error.toString(),
        onRetry: () => ref.invalidate(expensesProvider),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const _EmptyState(message: 'No expenses yet');
        }

        final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(expensesProvider),
          color: AppTheme.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              _TotalCard(
                total: total,
                label: 'Total Expenses',
                color: AppTheme.error,
                formatter: formatter,
                isExpense: true,
              ),
              const SizedBox(height: 24),
              Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 12),
              ...expenses.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TransactionCard(
                    title: e.category,
                    subtitle: e.description,
                    amount: formatter.format(e.amount),
                    date: dateFormat.format(e.date),
                    isExpense: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Revenues View
class _RevenuesView extends ConsumerWidget {
  const _RevenuesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenuesAsync = ref.watch(revenuesProvider);
    final formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d');

    return revenuesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (error, _) => _ErrorState(
        error: error.toString(),
        onRetry: () => ref.invalidate(revenuesProvider),
      ),
      data: (revenues) {
        if (revenues.isEmpty) {
          return const _EmptyState(message: 'No revenue yet');
        }

        final total = revenues.fold<double>(0, (sum, r) => sum + r.totalAmount);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(revenuesProvider),
          color: AppTheme.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              _TotalCard(
                total: total,
                label: 'Total Revenue',
                color: AppTheme.success,
                formatter: formatter,
                isExpense: false,
              ),
              const SizedBox(height: 24),
              Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 12),
              ...revenues.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TransactionCard(
                    title: r.type,
                    subtitle:
                        '${r.quantity} kg @ ${formatter.format(r.pricePerUnit)}/kg${r.buyer != null ? ' • ${r.buyer}' : ''}',
                    amount: formatter.format(r.totalAmount),
                    date: dateFormat.format(r.date),
                    isExpense: false,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// === WIDGETS ===

class _TotalCard extends StatelessWidget {
  final double total;
  final String label;
  final Color color;
  final NumberFormat formatter;
  final bool isExpense;

  const _TotalCard({
    required this.total,
    required this.label,
    required this.color,
    required this.formatter,
    this.isExpense = true,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = isExpense
        ? [AppTheme.error, const Color(0xFFEF4444)]
        : [AppTheme.primary, AppTheme.primaryLight];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isExpense ? Iconsax.arrow_up : Iconsax.arrow_down,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            formatter.format(total),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String date;
  final bool isExpense;

  const _TransactionCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.grey100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkGrey : AppTheme.grey200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isExpense ? AppTheme.error : AppTheme.primary).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getIconForCategory(title),
              color: isExpense ? AppTheme.error : AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.black,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.grey600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isExpense ? '-$amount' : '+$amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isExpense ? AppTheme.error : AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkGrey : AppTheme.grey400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    if (!isExpense) return Iconsax.money_send;

    switch (category.toLowerCase()) {
      case 'feed':
        return Iconsax.box;
      case 'labor':
        return Iconsax.profile_2user;
      case 'equipment':
        return Iconsax.setting_2;
      case 'transport':
        return Iconsax.truck;
      case 'supplies':
        return Iconsax.archive;
      case 'marketing':
        return Iconsax.monitor;
      case 'maintenance':
        return Iconsax.setting_2;
      case 'fingerlings':
        return Iconsax.computing;
      default:
        return Iconsax.receipt_2;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first transaction',
              style: TextStyle(color: AppTheme.grey600),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 24),
            Text(
              'Failed to load',
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
              style: TextStyle(color: AppTheme.grey600),
            ),
            const SizedBox(height: 24),
            CustomButton.outlined(
              text: 'Try Again',
              onPressed: onRetry,
              width: 140,
            ),
          ],
        ),
      ),
    );
  }
}
