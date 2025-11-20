import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../data/inventory_repository.dart';
import '../../formulation/data/formulation_repository.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../auth/data/auth_repository.dart';

/// Inventory Tab - Stock management with clear status indicators
/// Large touch targets, high contrast for outdoor use
class InventoryTab extends ConsumerWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final inventoryAsync = ref.watch(inventoryRepositoryProvider);
    final formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = userAsync.value;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.white,
      appBar: AppBar(
        title: const Text('Stock'),
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.white,
        surfaceTintColor: Colors.transparent,
        actions: user != null
            ? [
                IconButton(
                  icon: const Icon(Iconsax.add_circle, color: AppTheme.primary),
                  onPressed: () => _showAddStockSheet(context, ref),
                  tooltip: 'Add Stock',
                ),
              ]
            : null,
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (_, __) => const AuthRequiredView(
          featureName: 'Stock Management',
          description:
              'Track your feed, fingerlings, and equipment inventory in real-time.',
          icon: Icons.inventory_2_outlined,
        ),
        data: (user) => user == null
            ? const AuthRequiredView(
                featureName: 'Stock Management',
                description:
                    'Track your feed, fingerlings, and equipment inventory in real-time.',
                icon: Icons.inventory_2_outlined,
              )
            : inventoryAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (error, _) => _ErrorState(
                  error: error.toString(),
                  onRetry: () => ref.invalidate(inventoryRepositoryProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyState(
                      onAdd: () => _showAddStockSheet(context, ref),
                    );
                  }

                  // Sort: low stock first
                  final sorted = List<InventoryItem>.from(items);
                  sorted.sort((a, b) {
                    if (a.isLowStock && !b.isLowStock) return -1;
                    if (!a.isLowStock && b.isLowStock) return 1;
                    return a.ingredientName.compareTo(b.ingredientName);
                  });

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(inventoryRepositoryProvider),
                    color: AppTheme.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = sorted[index];
                        return _InventoryCard(
                          item: item,
                          formatter: formatter,
                          onTap: () => _showEditStockSheet(context, ref, item),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showAddStockSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddStockSheet(),
    );
  }

  void _showEditStockSheet(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) {
    final quantityController = TextEditingController(
      text: item.currentQuantity.toStringAsFixed(1),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ingredientName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update stock quantity',
                        style: TextStyle(fontSize: 14, color: AppTheme.grey600),
                      ),
                    ],
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
              'New Quantity (kg)',
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.black,
              ),
              decoration: const InputDecoration(suffixText: 'kg'),
            ),
            const SizedBox(height: 24),

            CustomButton.primary(
              text: 'Update Stock',
              onPressed: () async {
                final qty = double.tryParse(quantityController.text);
                if (qty == null) return;

                try {
                  await ref
                      .read(inventoryRepositoryProvider.notifier)
                      .updateStock(item.id, currentQuantity: qty);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock updated'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Add Stock Sheet - Select ingredient from list
class _AddStockSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<_AddStockSheet> {
  Ingredient? _selectedIngredient;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  'Add Stock',
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

          // Ingredient Dropdown
          Text(
            'Select Ingredient',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 8),
          ingredientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Failed to load ingredients',
              style: TextStyle(color: AppTheme.error),
            ),
            data: (ingredients) => Container(
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonFormField<Ingredient>(
                value: _selectedIngredient,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                hint: const Text('Choose ingredient'),
                isExpanded: true,
                items: ingredients
                    .map(
                      (ing) =>
                          DropdownMenuItem(value: ing, child: Text(ing.name)),
                    )
                    .toList(),
                onChanged: (ing) {
                  setState(() {
                    _selectedIngredient = ing;
                    if (ing != null && ing.defaultPrice > 0) {
                      _priceController.text = ing.defaultPrice.toStringAsFixed(
                        0,
                      );
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quantity & Price
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
                      controller: _quantityController,
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
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '0'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: TextStyle(color: AppTheme.error)),
            ),

          CustomButton.primary(
            text: 'Add Stock',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _addStock,
          ),
        ],
      ),
    );
  }

  Future<void> _addStock() async {
    if (_selectedIngredient == null) {
      setState(() => _error = 'Please select an ingredient');
      return;
    }

    final qty = double.tryParse(_quantityController.text);
    final price = double.tryParse(_priceController.text);

    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref
          .read(inventoryRepositoryProvider.notifier)
          .addStock(
            ingredientId: _selectedIngredient!.id,
            quantityKg: qty,
            pricePerKg: price ?? 0,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock added'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }
}

/// Inventory Card
class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final NumberFormat formatter;
  final VoidCallback onTap;

  const _InventoryCard({
    required this.item,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLow = item.isLowStock;
    final double progress = (item.currentQuantity / 100).clamp(
      0,
      1,
    ); // Mock 100kg max for visual

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLow
                ? AppTheme.warning.withValues(alpha: 0.5)
                : (isDark ? AppTheme.darkGrey : AppTheme.grey200),
            width: 1.5,
          ),
          boxShadow: AppTheme.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: (isLow ? AppTheme.warning : AppTheme.primary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isLow ? Iconsax.warning_2 : Iconsax.box_1,
                        color: isLow ? AppTheme.warning : AppTheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.ingredientName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatter.format(item.unitPrice)} / kg',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.grey600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.currentQuantity.toStringAsFixed(0)}kg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isLow ? AppTheme.warning : AppTheme.primary,
                          ),
                        ),
                        Text(
                          'IN STOCK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.grey400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Visual Progress Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isLow ? 'Low Stock Warning' : 'Stock Level',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLow ? AppTheme.warning : AppTheme.grey600,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isLow ? AppTheme.warning : AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkGrey : AppTheme.grey100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isLow
                                  ? [AppTheme.warning, const Color(0xFFFBBF24)]
                                  : AppTheme.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isLow
                                            ? AppTheme.warning
                                            : AppTheme.primary)
                                        .withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty State
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.grey400),
            const SizedBox(height: 24),
            Text(
              'No stock items yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first ingredient to start tracking',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey600),
            ),
            const SizedBox(height: 24),
            CustomButton.primary(
              text: 'Add Stock',
              onPressed: onAdd,
              width: 160,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error State
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
              'Failed to load stock',
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
