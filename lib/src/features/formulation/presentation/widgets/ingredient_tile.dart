import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/formulation_repository.dart';

/// Clean ingredient selection tile
class IngredientTile extends StatelessWidget {
  final Ingredient ingredient;
  final bool isSelected;
  final double? customPrice;
  final VoidCallback onToggle;
  final Function(double?) onPriceChanged;

  const IngredientTile({
    super.key,
    required this.ingredient,
    required this.isSelected,
    this.customPrice,
    required this.onToggle,
    required this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final price = customPrice ?? ingredient.defaultPrice;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          children: [
            // Checkbox
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.grey400,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),

            // Name + Price + Nutrients
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₦${price.toStringAsFixed(0)}/${ingredient.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildNutrientBadge(
                        'CP',
                        '${ingredient.nutrients['protein']?.toStringAsFixed(1) ?? '0'}%',
                        isWarning: (ingredient.nutrients['protein'] ?? 0) <= 0,
                      ),
                      const SizedBox(width: 4),
                      _buildNutrientBadge(
                        'ME',
                        '${ingredient.nutrients['energy']?.toStringAsFixed(0) ?? '0'}',
                        isWarning: (ingredient.nutrients['energy'] ?? 0) <= 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Edit button
            GestureDetector(
              onTap: () => _showPriceEditor(context),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.grey600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientBadge(
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isWarning
            ? AppTheme.errorRed.withValues(alpha: 0.1)
            : AppTheme.grey100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWarning)
            const Icon(
              Icons.warning_amber_rounded,
              size: 10,
              color: AppTheme.errorRed,
            ),
          if (isWarning) const SizedBox(width: 2),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isWarning ? AppTheme.errorRed : AppTheme.grey600,
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onPriceChanged(double.tryParse(controller.text));
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
