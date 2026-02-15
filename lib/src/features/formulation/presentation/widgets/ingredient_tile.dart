import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/formulation_repository.dart';

/// Clean ingredient selection tile
class IngredientTile extends StatelessWidget {
  final Ingredient ingredient;
  final bool isSelected;
  final double? customPrice;
  final double? minInclusionPct;
  final double? maxInclusionPct;
  final VoidCallback onToggle;
  final Function(double?) onPriceChanged;
  final Function(double?, double?) onConstraintsChanged;

  const IngredientTile({
    super.key,
    required this.ingredient,
    required this.isSelected,
    this.customPrice,
    this.minInclusionPct,
    this.maxInclusionPct,
    required this.onToggle,
    required this.onPriceChanged,
    required this.onConstraintsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final price = customPrice ?? ingredient.defaultPrice;
    final protein = ingredient.nutrients['protein'] ?? 0;
    final energy = ingredient.nutrients['energy'] ?? 0;
    final categoryLabel = _friendlyCategory(ingredient.category);
    final hasCustomPrice =
        customPrice != null && customPrice != ingredient.defaultPrice;
    final hasLimits = minInclusionPct != null || maxInclusionPct != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.grey200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.grey400,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.black,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Selected',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMetaBadge(
                          icon: Icons.category_outlined,
                          text: categoryLabel,
                        ),
                        _buildMetaBadge(
                          icon: Icons.payments_outlined,
                          text:
                              '₦${price.toStringAsFixed(0)}/${ingredient.unit}',
                          highlight: hasCustomPrice,
                        ),
                        if (hasCustomPrice)
                          _buildMetaBadge(
                            icon: Icons.auto_fix_high_rounded,
                            text: 'Custom',
                            highlight: true,
                          ),
                      ],
                    ),
                    if (isSelected || hasLimits) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildMetaBadge(
                            icon: Icons.fitness_center_outlined,
                            text: 'CP ${protein.toStringAsFixed(1)}%',
                            highlight: protein > 40,
                          ),
                          _buildMetaBadge(
                            icon: Icons.bolt_outlined,
                            text: 'ME ${energy.toStringAsFixed(0)}',
                          ),
                        ],
                      ),
                    ],
                    if (hasLimits) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Limits: ${minInclusionPct?.toStringAsFixed(1) ?? '-'}% min, ${maxInclusionPct?.toStringAsFixed(1) ?? '-'}% max',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: () => _showPriceEditor(context),
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppTheme.grey600,
                  ),
                  tooltip: 'Edit price and limits',
                  constraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  splashRadius: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyCategory(String value) {
    switch (value) {
      case 'PROTEIN':
        return 'Protein source';
      case 'CARBOHYDRATE':
      case 'FIBER':
        return 'Energy source';
      case 'MINERALS':
        return 'Minerals and vitamins';
      default:
        return value.replaceAll('_', ' ').toLowerCase();
    }
  }

  Widget _buildMetaBadge({
    required IconData icon,
    required String text,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryGreen.withValues(alpha: 0.12)
            : AppTheme.grey100,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: highlight ? AppTheme.primaryGreen : AppTheme.grey600,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: highlight ? AppTheme.primaryGreen : AppTheme.grey600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPriceEditor(BuildContext context) {
    final controller = TextEditingController(
      text: (customPrice ?? ingredient.defaultPrice).toStringAsFixed(0),
    );
    final minController = TextEditingController(
      text: minInclusionPct?.toStringAsFixed(1) ?? '',
    );
    final maxController = TextEditingController(
      text: maxInclusionPct?.toStringAsFixed(1) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ingredient.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '₦ ',
                suffixText: '/ ${ingredient.unit}',
                filled: true,
                fillColor: AppTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Min % (optional)',
                      filled: true,
                      fillColor: AppTheme.grey100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max % (optional)',
                      filled: true,
                      fillColor: AppTheme.grey100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onPriceChanged(double.tryParse(controller.text));
                  onConstraintsChanged(
                    double.tryParse(minController.text),
                    double.tryParse(maxController.text),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
