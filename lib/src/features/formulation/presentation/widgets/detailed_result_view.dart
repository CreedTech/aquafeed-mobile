import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/formulation_repository.dart';

/// Clean result view showing formulation details
class DetailedResultView extends StatelessWidget {
  final FormulationResult result;

  const DetailedResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cost Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grey200),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cost',
                        style: TextStyle(color: AppTheme.grey600),
                      ),
                      Text(
                        result.isUnlocked
                            ? currencyFormatter.format(result.totalCost)
                            : '₦ 84,500', // Dummy for blur teasing
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cost per kg',
                        style: TextStyle(color: AppTheme.grey600),
                      ),
                      Text(
                        result.isUnlocked
                            ? '${currencyFormatter.format(result.costPerKg)}/kg'
                            : '₦ 1,250/kg', // Dummy for blur teasing
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quality Match',
                        style: TextStyle(color: AppTheme.grey600),
                      ),
                      Text(
                        result.isUnlocked
                            ? '${result.qualityMatch.toStringAsFixed(1)}%'
                            : '98.5%', // Dummy for blur teasing
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Compliance',
                        style: TextStyle(color: AppTheme.grey600),
                      ),
                      result.isUnlocked
                          ? _ComplianceBadge(color: result.complianceColor)
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.grey200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Reviewing',
                                style: TextStyle(
                                  color: AppTheme.grey600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
              if (!result.isUnlocked)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Nutrient Comparison (Excel-style per-nutrient feedback)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nutrient Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (!result.isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: AppTheme.grey600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Parameter',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Target',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Actual',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 70), // Status column
                      ],
                    ),
                  ),
                  // Nutrient rows
                  ...result.nutrientStatuses.map(
                    (status) => _NutrientStatusRow(
                      status: status,
                      isUnlocked: result.isUnlocked,
                    ),
                  ),
                ],
              ),
            ),
            if (!result.isUnlocked)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
            if (!result.isUnlocked)
              const Positioned.fill(
                child: _PremiumUnlockOverlay(title: 'Unlock to view Analysis'),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Ingredients List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ingredients',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (!result.isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: AppTheme.grey600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (result.ingredientsUsed != null &&
            result.ingredientsUsed!.isNotEmpty)
          Stack(
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 150),
                width: double.infinity,
                child: Column(
                  children: result.ingredientsUsed!
                      .map(
                        (item) => _IngredientRow(
                          item: item,
                          isUnlocked: result.isUnlocked,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (!result.isUnlocked)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              if (!result.isUnlocked)
                const Positioned.fill(
                  child: _PremiumUnlockOverlay(title: 'Unlock to view Recipe'),
                ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Unlock to view ingredients',
                style: TextStyle(color: AppTheme.grey600),
              ),
            ),
          ),
      ],
    );
  }
}

/// Row for each nutrient with color-coded status
class _NutrientStatusRow extends StatelessWidget {
  final NutrientStatus status;
  final bool isUnlocked;
  const _NutrientStatusRow({required this.status, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    // Format nutrient name nicely
    final displayName = _formatNutrientName(status.nutrient);

    // Mask Target range for demo
    String targetDisplay;
    if (!isUnlocked) {
      targetDisplay = 'XX.X%';
    } else if (status.targetMin != null && status.targetMax != null) {
      targetDisplay =
          '${status.targetMin!.toStringAsFixed(1)}-${status.targetMax!.toStringAsFixed(1)}%';
    } else {
      targetDisplay = '${status.targetValue.toStringAsFixed(1)}%';
    }

    // Color and text based on status
    Color statusColor;
    String statusText;
    switch (status.status) {
      case 'Below':
        statusColor = Colors.red;
        statusText = 'Increase';
        break;
      case 'Above':
        statusColor = AppTheme.primaryGreen;
        statusText = 'Reduce';
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'OK';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.grey100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              targetDisplay,
              style: TextStyle(color: AppTheme.grey600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              isUnlocked ? '${status.actual.toStringAsFixed(1)}%' : '--',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 70,
            child: isUnlocked
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.grey200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '---',
                      style: TextStyle(
                        color: AppTheme.grey600,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatNutrientName(String nutrient) {
    switch (nutrient.toLowerCase()) {
      case 'protein':
        return 'Protein';
      case 'fat':
        return 'Fat';
      case 'fiber':
        return 'Fiber';
      case 'ash':
        return 'Ash';
      case 'lysine':
        return 'Lysine';
      case 'methionine':
        return 'Methionine';
      case 'calcium':
        return 'Calcium';
      case 'phosphorous':
        return 'Phosphorous';
      default:
        return nutrient;
    }
  }
}

class _ComplianceBadge extends StatelessWidget {
  final String color;
  const _ComplianceBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (color.toUpperCase()) {
      case 'GREEN':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'Compliant';
        break;
      case 'YELLOW':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        label = 'Partial';
        break;
      default:
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'Non-Compliant';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final IngredientUsed item;
  final bool isUnlocked;
  const _IngredientRow({required this.item, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Show "(Auto)" badge for auto-calculated ingredients like Vitamin C
                if (item.isAutoCalculated) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Auto',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isUnlocked) ...[
            Text(
              '${item.qtyKg.toStringAsFixed(1)} kg',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (item.bags > 0) ...[
              const SizedBox(width: 8),
              Text(
                '(${item.bags} bag${item.bags > 1 ? 's' : ''})',
                style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.grey200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: AppTheme.grey600,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Locked',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumUnlockOverlay extends StatelessWidget {
  final String title;

  const _PremiumUnlockOverlay({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Icon(
          Icons.lock_rounded,
          size: 32,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}
