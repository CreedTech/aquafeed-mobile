import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/formulation_repository.dart';

/// Strategy comparison widget showing Economy, Balanced, Premium options
class StrategyComparison extends StatelessWidget {
  final List<FormulationResult> results;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const StrategyComparison({
    super.key,
    required this.results,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    // SORT results by cost: cheapest first, most expensive last
    final sortedResults = List<FormulationResult>.from(results)
      ..sort((a, b) => a.totalCost.compareTo(b.totalCost));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Strategy',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Same ingredients, different optimization goals',
          style: TextStyle(fontSize: 13, color: AppTheme.grey600),
        ),
        const SizedBox(height: 16),

        // Strategy options - display in sorted order
        ...List.generate(sortedResults.length, (sortedIndex) {
          final result = sortedResults[sortedIndex];
          // Map back to original index for selection
          final originalIndex = results.indexOf(result);
          final isSelected = originalIndex == selectedIndex;

          String title;
          String subtitle;
          IconData icon;
          String badge;

          // Assign labels based on sorted POSITION, not backend strategy
          if (sortedIndex == 0) {
            // Cheapest option
            title = 'Economy';
            subtitle = 'Optimized for lowest cost';
            icon = Icons.savings_outlined;
            badge = 'Budget-friendly';
          } else if (sortedIndex == sortedResults.length - 1) {
            // Most expensive option
            title = 'Premium';
            subtitle = 'Highest quality ingredients';
            icon = Icons.star_outline;
            badge = 'Best Quality';
          } else {
            // Middle option
            title = 'Balanced';
            subtitle = 'Best value for quality and cost';
            icon = Icons.balance_outlined;
            badge = 'Recommended';
          }

          return GestureDetector(
            onTap: () => onSelect(originalIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.grey200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppTheme.grey100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : AppTheme.grey600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.black,
                                  ),
                                ),
                                if (badge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : AppTheme.grey100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.grey600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : AppTheme.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatter.format(result.totalCost),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppTheme.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatter.format(result.costPerKg)}/kg',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppTheme.grey600,
                            ),
                          ),
                        ],
                      ),

                      // Check mark for selected
                      if (isSelected) ...[
                        const SizedBox(width: 12),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // Context-aware hint based on selection
        if (results.isNotEmpty)
          _buildSelectionHint(results, selectedIndex, formatter),
      ],
    );
  }

  Widget _buildSelectionHint(
    List<FormulationResult> results,
    int selectedIndex,
    NumberFormat formatter,
  ) {
    if (selectedIndex >= results.length) return const SizedBox.shrink();

    final selected = results[selectedIndex];
    final sortedByCost = List<FormulationResult>.from(results)
      ..sort((a, b) => a.totalCost.compareTo(b.totalCost));
    final cheapest = sortedByCost.first;
    final mostExpensive = sortedByCost.last;

    String hint;

    if (selected.strategy == 'LEAST_COST') {
      // User selected Economy
      final qualityDiff = (mostExpensive.qualityMatch - selected.qualityMatch)
          .abs();
      if (qualityDiff > 5) {
        hint =
            'You save ${formatter.format(mostExpensive.totalCost - selected.totalCost)} vs Premium, with ${qualityDiff.toStringAsFixed(0)}% lower quality match.';
      } else {
        hint =
            'Most affordable option while still meeting nutritional requirements.';
      }
    } else if (selected.strategy == 'BALANCED') {
      // User selected Balanced
      final savings = selected.totalCost - cheapest.totalCost;
      final qualityGain = (selected.qualityMatch - cheapest.qualityMatch).abs();
      hint =
          'Adds ${formatter.format(savings)} over Economy for ${qualityGain.toStringAsFixed(0)}% better quality match.';
    } else {
      // User selected Premium
      final extra = selected.totalCost - cheapest.totalCost;
      final qualityGain = (selected.qualityMatch - cheapest.qualityMatch).abs();
      hint =
          'Costs ${formatter.format(extra)} more than Economy for ${qualityGain.toStringAsFixed(0)}% better quality match.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.grey600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
