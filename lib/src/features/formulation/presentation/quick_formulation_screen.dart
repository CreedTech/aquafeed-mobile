import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../../shared/paywall_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/formulation_repository.dart';
import 'widgets/aura_loader.dart';
import 'widgets/detailed_result_view.dart';

class QuickFormulationScreen extends ConsumerStatefulWidget {
  const QuickFormulationScreen({super.key});

  @override
  ConsumerState<QuickFormulationScreen> createState() =>
      _QuickFormulationScreenState();
}

class _QuickFormulationScreenState
    extends ConsumerState<QuickFormulationScreen> {
  int _selectedTemplateIndex = 0;
  double _targetWeight = 100;
  String? _selectedStandardId;
  final _formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Initial check for user access to set reasonable default weight
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user != null && !user.hasFullAccess && _targetWeight > 5) {
        setState(() => _targetWeight = 5);
      }
    });
  }

  Future<void> _handleUnlock(FormulationResult result) async {
    final formulationId = result.formulationId;
    if (formulationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Production Mix'),
        content: const Text(
          'This will deduct ₦10,000 from your wallet to unlock the full production recipe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Processing payment...')));

      final unlockedResult = await ref
          .read(formulationProvider.notifier)
          .unlock(formulationId);

      if (unlockedResult != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formulation unlocked successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        // Removed ref.invalidate to keep the screen open
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final errorMsg = e.toString().contains('Insufficient balance')
          ? 'Insufficient balance. Please top up your wallet.'
          : 'Failed to unlock: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppTheme.errorRed,
          action: e.toString().contains('Insufficient balance')
              ? SnackBarAction(
                  label: 'Deposit',
                  textColor: Colors.white,
                  onPressed: () => context.push('/wallet'),
                )
              : null,
        ),
      );
    }
  }

  void _goBack() {
    ref.read(formulationProvider.notifier).reset();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final formulationState = ref.watch(formulationProvider);
    final standardsAsync = ref.watch(feedStandardsProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final templatesAsync = ref.watch(feedTemplatesProvider);

    // Check auth - show sign-in view if not logged in
    // Use hasValue to keep showing current content during background refreshes
    if (userAsync.hasValue) {
      final user = userAsync.value;
      if (user == null) {
        return _buildAuthRequired();
      }
      return _buildMainContent(
        formulationState,
        standardsAsync,
        ingredientsAsync,
        templatesAsync,
      );
    }

    return userAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.white,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildAuthRequired(),
      data: (_) => const SizedBox.shrink(), // Handled above
    );
  }

  Widget _buildAuthRequired() {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Quick Mix'),
        backgroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: const AuthRequiredView(
        featureName: 'Quick Formulation',
        description:
            'Sign in to use quick templates for instant feed formulations.',
        icon: Icons.flash_on_outlined,
      ),
    );
  }

  Widget _buildMainContent(
    AsyncValue<List<FormulationResult>?> formulationState,
    AsyncValue<List<FeedStandard>> standardsAsync,
    AsyncValue<List<Ingredient>> ingredientsAsync,
    AsyncValue<List<FeedTemplate>> templatesAsync,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: AppTheme.black,
          ),
          onPressed: _goBack,
        ),
        title: const Text(
          'Quick Formulation',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: formulationState.when(
        data: (results) => results != null && results.isNotEmpty
            ? _ResultView(
                result: results.first,
                formatter: _formatter,
                onReset: () {
                  ref.read(formulationProvider.notifier).reset();
                },
                onUnlock: () => _handleUnlock(results.first),
              )
            : _buildForm(standardsAsync, ingredientsAsync, templatesAsync),
        loading: () => const Center(child: AuraLoader()),
        error: (error, _) {
          if (error is PaymentRequiredException) {
            return PaywallView(
              featureName: 'Quick Formulation',
              description: error.message,
              icon: Icons.lock_outline,
            );
          }
          return _ErrorView(
            error: error.toString(),
            onRetry: () {
              ref.read(formulationProvider.notifier).reset();
            },
          );
        },
      ),
    );
  }

  Widget _buildForm(
    AsyncValue<List<FeedStandard>> standardsAsync,
    AsyncValue<List<Ingredient>> ingredientsAsync,
    AsyncValue<List<FeedTemplate>> templatesAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Template selection
        const Text(
          'Choose Template',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
        const SizedBox(height: 12),
        templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (templates) {
            if (templates.isEmpty) return const Text('No templates found');
            return Column(
              children: List.generate(templates.length, (index) {
                final template = templates[index];
                final isSelected = index == _selectedTemplateIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTemplateIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.grey200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.grey400,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                template.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.grey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),

        const SizedBox(height: 24),

        // Target weight
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.grey100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Batch Weight',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.grey600,
                    ),
                  ),
                  if (!(ref.watch(currentUserProvider).value?.hasFullAccess ??
                      false))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DEMO: MAX 5KG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final hasFullAccess =
                            ref
                                .watch(currentUserProvider)
                                .value
                                ?.hasFullAccess ??
                            false;
                        final minWeight = hasFullAccess ? 10.0 : 1.0;
                        final maxWeight = hasFullAccess ? 1000.0 : 5.0;
                        final divisions = hasFullAccess ? 99 : 4;

                        // Ensure current value is within valid range
                        double safeWeight = _targetWeight;
                        if (safeWeight < minWeight) safeWeight = minWeight;
                        if (safeWeight > maxWeight) safeWeight = maxWeight;

                        return Slider(
                          value: safeWeight,
                          min: minWeight,
                          max: maxWeight,
                          divisions: divisions,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: (v) => setState(() => _targetWeight = v),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_targetWeight.toInt()} kg',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Feed standard
        const Text(
          'Feed Standard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
        const SizedBox(height: 12),
        standardsAsync.when(
          loading: () => Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          error: (e, _) => Text(
            'Error loading standards',
            style: TextStyle(color: AppTheme.errorRed),
          ),
          data: (standards) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStandardId,
                hint: const Text('Select standard...'),
                isExpanded: true,
                items: standards
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedStandardId = v),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Calculate button
        ingredientsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (ingredients) => templatesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (templates) => ElevatedButton(
              onPressed: _selectedStandardId != null && templates.isNotEmpty
                  ? () => _calculate(
                      ingredients,
                      templates[_selectedTemplateIndex],
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.grey200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Calculate',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Switch to manual
        Center(
          child: TextButton(
            onPressed: () => context.go('/formulation'),
            child: Text(
              'Manual ingredient selection',
              style: TextStyle(
                color: AppTheme.grey600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  void _calculate(List<Ingredient> allIngredients, FeedTemplate template) {
    final selected = <SelectedIngredient>[];

    for (final name in template.ingredientNames) {
      final ingredient = allIngredients.firstWhere(
        (i) => i.name.toUpperCase() == name.toUpperCase(),
        orElse: () => Ingredient(
          id: '',
          name: '',
          category: '',
          defaultPrice: 0,
          unit: '',
          nutrients: {},
        ),
      );
      if (ingredient.id.isNotEmpty) {
        // Use database price only - no hardcoded fallbacks
        selected.add(
          SelectedIngredient(
            ingredientId: ingredient.id,
            customPrice: ingredient.defaultPrice > 0
                ? ingredient.defaultPrice
                : null,
          ),
        );
      }
    }

    if (selected.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Not enough ingredients matched. Try manual selection.',
          ),
        ),
      );
      return;
    }

    ref
        .read(formulationProvider.notifier)
        .calculate(
          FormulationRequest(
            targetWeightKg: _targetWeight,
            standardId: _selectedStandardId!,
            selectedIngredients: selected,
          ),
        );
  }
}

class _ResultView extends StatelessWidget {
  final FormulationResult result;
  final NumberFormat formatter;
  final VoidCallback onReset;
  final VoidCallback onUnlock;

  const _ResultView({
    required this.result,
    required this.formatter,
    required this.onReset,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Success header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Formulation Complete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ${formatter.format(result.totalCost)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (result.isDemo) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppTheme.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.black.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demo Calculation',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Demo Mix: Quantities for your full target weight are hidden. Unlock to reveal exact ratios and mixing instructions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Results
          DetailedResultView(result: result),

          const SizedBox(height: 24),

          if (!result.isUnlocked) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUnlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_open_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Unlock Production Mix (₦10,000)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // New formulation button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'New Formulation',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.grey400),
            const SizedBox(height: 16),
            Text(
              'Optimization failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error.replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
