import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:no_screenshot/no_screenshot.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/formulation_repository.dart';
import 'widgets/aura_loader.dart';
import 'widgets/step_indicator.dart';
import 'widgets/strategy_comparison.dart';
import 'widgets/detailed_result_view.dart';
import 'widgets/ingredient_tile.dart';
import 'widgets/standard_tile.dart';
import '../../../shared/paywall_view.dart';

class FormulationScreen extends ConsumerStatefulWidget {
  final int initialStep;
  const FormulationScreen({super.key, this.initialStep = 0});

  @override
  ConsumerState<FormulationScreen> createState() => _FormulationScreenState();
}

class _FormulationScreenState extends ConsumerState<FormulationScreen>
    with SingleTickerProviderStateMixin {
  late int _currentStep;
  late TabController _tabController;
  late TextEditingController _searchController;
  int _selectedOptionIndex = 0;
  String _searchQuery = '';

  final Set<String> _selectedIngredientIds = {};
  final Map<String, double> _customPrices = {};
  double _targetWeight = 100;
  String? _selectedStandardId;
  double _overheadCost = 0; // Milling, processing, pelletizing, transport
  String _selectedCategory = 'Catfish';
  String? _selectedPoultryType;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });

    // Initial check for user access to set reasonable default weight
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user != null && !user.hasFullAccess && _targetWeight > 5) {
        setState(() => _targetWeight = 5);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _disablePrivacy();
    super.dispose();
  }

  Future<void> _enablePrivacy() async {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      await NoScreenshot.instance.screenshotOff();
    } catch (e) {
      debugPrint('Privacy enable error: $e');
    }
  }

  Future<void> _disablePrivacy() async {
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      await NoScreenshot.instance.screenshotOn();
    } catch (e) {
      debugPrint('Privacy disable error: $e');
    }
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
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Processing payment...')));

      final unlockedResult = await ref
          .read(formulationProvider.notifier)
          .unlock(formulationId);

      if (unlockedResult != null && mounted) {
        // Clear snacker
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formulation unlocked successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );

        // Final state update will be handled by the repo refresh
        // but we can also manually switch to the unlocked result
        // if the repo doesn't automatically update the list.
        // For now, let's just invalidate user to update wallet
        // and avoid invalidating formulationProvider to keep screen open
        ref.invalidate(currentUserProvider);

        // Stay on screen
        _enablePrivacy();
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
    if (_currentStep == 0) {
      // On first step, close the screen
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        context.go('/dashboard');
      }
    } else if (_currentStep == 2) {
      // On result step, go back to config step
      _disablePrivacy();
      ref.read(formulationProvider.notifier).reset();
      setState(() => _currentStep = 1);
    } else {
      // Go back one step
      setState(() => _currentStep = _currentStep - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final standardsAsync = ref.watch(feedStandardsProvider);
    final formulationState = ref.watch(formulationProvider);

    // Check auth - show sign-in view if not logged in
    // Use hasValue to keep showing current content during background refreshes
    if (userAsync.hasValue) {
      final user = userAsync.value;
      if (user == null) {
        return _buildAuthRequired();
      }
      return _buildMainContent(
        ingredientsAsync,
        standardsAsync,
        formulationState,
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
        title: const Text('Create Mix'),
        backgroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: const AuthRequiredView(
        featureName: 'Feed Formulation',
        description:
            'Sign in to create optimized feed formulations with real-time cost analysis.',
        icon: Icons.science_outlined,
      ),
    );
  }

  Widget _buildMainContent(
    AsyncValue<List<Ingredient>> ingredientsAsync,
    AsyncValue<List<FeedStandard>> standardsAsync,
    AsyncValue<List<FormulationResult>?> formulationState,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          _currentStep == 0
              ? 'Select Ingredients'
              : _currentStep == 1
              ? 'Configure Mix'
              : 'Results',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            _currentStep == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
            size: 22,
            color: AppTheme.black,
          ),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: StepIndicator(currentStep: _currentStep),
          ),

          // Content
          Expanded(
            child: _currentStep == 0
                ? _buildIngredientSelection(ingredientsAsync)
                : _currentStep == 1
                ? _buildConfigStep(standardsAsync)
                : _buildResultStep(formulationState),
          ),

          // Bottom action (only on step 0 and 1)
          if (_currentStep < 2) _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildIngredientSelection(
    AsyncValue<List<Ingredient>> ingredientsAsync,
  ) {
    return ingredientsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load ingredients',
              style: TextStyle(color: AppTheme.grey600),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(ingredientsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (ingredients) {
        if (ingredients.isEmpty) {
          return const Center(child: Text('No ingredients available'));
        }

        final filteredIngredients = ingredients.where((i) {
          if (_searchQuery.isEmpty) return true;
          return i.name.toLowerCase().contains(_searchQuery);
        }).toList();

        final proteins = filteredIngredients
            .where((i) => i.category == 'PROTEIN')
            .toList();
        final energy = filteredIngredients
            .where((i) => i.category == 'CARBOHYDRATE' || i.category == 'FIBER')
            .toList();
        final others = filteredIngredients
            .where(
              (i) =>
                  i.category != 'PROTEIN' &&
                  i.category != 'CARBOHYDRATE' &&
                  i.category != 'FIBER',
            )
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search ingredients...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.grey400),
                  filled: true,
                  fillColor: AppTheme.grey100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.grey600,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.primaryGreen,
                ),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Proteins'),
                  Tab(text: 'Energy'),
                  Tab(text: 'Others'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIngredientList(proteins),
                  _buildIngredientList(energy),
                  _buildIngredientList(others),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIngredientList(List<Ingredient> ingredients) {
    if (ingredients.isEmpty) {
      return Center(
        child: Text(
          'No ingredients in this category',
          style: TextStyle(color: AppTheme.grey600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        final ing = ingredients[index];
        return IngredientTile(
          ingredient: ing,
          isSelected: _selectedIngredientIds.contains(ing.id),
          customPrice: _customPrices[ing.id],
          onToggle: () => setState(() {
            if (_selectedIngredientIds.contains(ing.id)) {
              _selectedIngredientIds.remove(ing.id);
              _customPrices.remove(ing.id);
            } else {
              _selectedIngredientIds.add(ing.id);
            }
          }),
          onPriceChanged: (price) => setState(() {
            if (price != null && price != ing.defaultPrice) {
              _customPrices[ing.id] = price;
            } else {
              _customPrices.remove(ing.id);
            }
          }),
        );
      },
    );
  }

  Widget _buildConfigStep(AsyncValue<List<FeedStandard>> standardsAsync) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Target weight section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.grey100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Target Weight (kg)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        const minWeight = 10.0;
                        const maxWeight = 5000.0;
                        const divisions = 499;

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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Feed category selection
        const Text(
          'Feed Category',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CategoryButton(
                label: 'Catfish',
                icon: Icons.set_meal_outlined,
                isSelected: _selectedCategory == 'Catfish',
                onTap: () => setState(() {
                  _selectedCategory = 'Catfish';
                  _selectedPoultryType = null;
                  _selectedStandardId = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CategoryButton(
                label: 'Poultry',
                icon: Icons.egg_outlined,
                isSelected: _selectedCategory == 'Poultry',
                onTap: () => setState(() {
                  _selectedCategory = 'Poultry';
                  _selectedPoultryType = 'Broiler';
                  _selectedStandardId = null;
                }),
              ),
            ),
          ],
        ),
        if (_selectedCategory == 'Poultry') ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Broiler'),
                  selected: _selectedPoultryType == 'Broiler',
                  onSelected: (selected) => setState(() {
                    _selectedPoultryType = 'Broiler';
                    _selectedStandardId = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Layer'),
                  selected: _selectedPoultryType == 'Layer',
                  onSelected: (selected) => setState(() {
                    _selectedPoultryType = 'Layer';
                    _selectedStandardId = null;
                  }),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // Feed standard selection
        Text(
          _selectedCategory == 'Catfish'
              ? 'Select Weight Range'
              : 'Select Growth Phase',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
        const SizedBox(height: 12),
        standardsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Failed to load standards: $e',
            style: const TextStyle(color: AppTheme.errorRed),
          ),
          data: (standards) {
            final filtered = standards
                .where(
                  (s) =>
                      s.feedCategory == _selectedCategory &&
                      (_selectedCategory != 'Poultry' ||
                          s.poultryType == _selectedPoultryType),
                )
                .toList();

            if (filtered.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No standards found for this selection'),
                ),
              );
            }
            return Column(
              children: filtered
                  .map(
                    (std) => StandardTile(
                      standard: std,
                      isSelected: _selectedStandardId == std.id,
                      onTap: () => setState(() => _selectedStandardId = std.id),
                    ),
                  )
                  .toList(),
            );
          },
        ),

        // Summary of selected ingredients
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                '${_selectedIngredientIds.length} ingredients selected',
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Other Costs (milling, processing, transport)
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.grey100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: AppTheme.grey600,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Other Costs (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Add milling, processing, pelletizing, or transport costs',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.grey600.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _overheadCost > 0 ? _overheadCost.toString() : '',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0',
                  prefixText: '₦ ',
                  prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value) ?? 0;
                  setState(() => _overheadCost = parsed);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultStep(
    AsyncValue<List<FormulationResult>?> formulationState,
  ) {
    return formulationState.when(
      loading: () => const Center(child: AuraLoader()),
      error: (err, _) => _buildErrorState(err.toString()),
      data: (results) {
        if (results == null || results.isEmpty) {
          return _buildErrorState('No formulation results. Please try again.');
        }

        // Ensure index is valid
        if (_selectedOptionIndex >= results.length) {
          _selectedOptionIndex = 0;
        }

        final result = results[_selectedOptionIndex];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Strategy comparison section
              StrategyComparison(
                results: results,
                selectedIndex: _selectedOptionIndex,
                onSelect: (index) =>
                    setState(() => _selectedOptionIndex = index),
              ),

              if (result.isDemo) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 24),

              // Selected result details
              DetailedResultView(result: result),
              const SizedBox(height: 24),

              // Action buttons
              if (!result.isUnlocked) ...[
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _handleUnlock(result),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.lock_open_rounded, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Complete Production Mix',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unlock full recipe for ₦10,000',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _disablePrivacy();
                        ref.read(formulationProvider.notifier).reset();
                        setState(() {
                          _currentStep = 0;
                          _selectedOptionIndex = 0;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(result.isUnlocked ? 'New Mix' : 'Try Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _disablePrivacy();
                        ref.read(formulationProvider.notifier).reset();
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          context.go('/dashboard');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: result.isUnlocked
                            ? AppTheme.primaryGreen
                            : AppTheme.grey200,
                        foregroundColor: result.isUnlocked
                            ? Colors.white
                            : AppTheme.grey600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(Object error) {
    if (error is PaymentRequiredException) {
      return PaywallView(
        featureName: 'Feed Formulation',
        description: error.message,
        icon: Icons.lock_outline,
      );
    }

    // Clean up the error message
    final cleanError = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('\\n\\n', '\n\n')
        .replaceAll('Tip: ', '\n\n');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              size: 32,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Adjustment Needed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              cleanError,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.grey600,
                height: 1.6,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(formulationProvider.notifier).reset();
                setState(() => _currentStep = 0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Edit Ingredients',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final ingredients = ref.read(ingredientsProvider).asData?.value ?? [];

    // Count selected by category
    final proteinCount = _selectedIngredientIds
        .where(
          (id) => ingredients.any((i) => i.id == id && i.category == 'PROTEIN'),
        )
        .length;
    final energyCount = _selectedIngredientIds
        .where(
          (id) => ingredients.any(
            (i) =>
                i.id == id &&
                (i.category == 'CARBOHYDRATE' || i.category == 'FIBER'),
          ),
        )
        .length;

    // Check for HIGH-QUALITY protein (>40% protein content)
    final highProteinCount = _selectedIngredientIds.where((id) {
      final ing = ingredients.firstWhere(
        (i) => i.id == id,
        orElse: () => Ingredient(
          id: '',
          name: '',
          category: '',
          defaultPrice: 0,
          unit: '',
          nutrients: {},
        ),
      );
      final proteinPct = ing.nutrients['protein'] ?? 0;
      return proteinPct > 40;
    }).length;

    // Validation messages
    List<String> warnings = [];
    if (proteinCount == 0) {
      warnings.add('Add at least 1 protein source');
    } else if (highProteinCount == 0) {
      warnings.add('Add a high-protein source (FISHMEAL, BLOOD MEAL)');
    }
    if (energyCount == 0) {
      warnings.add('Add at least 1 energy source (MAIZE, WHEAT)');
    }
    if (_selectedIngredientIds.length < 5) {
      warnings.add('Select at least 5 ingredients');
    }

    final bool canProceed = _currentStep == 0
        ? _selectedIngredientIds.length >= 5 &&
              proteinCount > 0 &&
              energyCount > 0
        : _selectedStandardId != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentStep == 0) ...[
              // Show warnings if any
              if (warnings.isNotEmpty && _selectedIngredientIds.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppTheme.grey600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warnings.join('\n'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Selection summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatusItem(
                      label: 'High Protein',
                      count: highProteinCount,
                      min: 1,
                    ),
                    _StatusItem(label: 'Energy', count: energyCount, min: 1),
                    _StatusItem(
                      label: 'Total',
                      count: _selectedIngredientIds.length,
                      min: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canProceed ? _handleNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.grey200,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep == 0 ? 'Continue' : 'Calculate',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
    } else {
      // Calculate formulation
      final request = FormulationRequest(
        targetWeightKg: _targetWeight,
        standardId: _selectedStandardId!,
        selectedIngredients: _selectedIngredientIds
            .map(
              (id) => SelectedIngredient(
                ingredientId: id,
                customPrice: _customPrices[id],
              ),
            )
            .toList(),
        overheadCost: _overheadCost,
      );

      _enablePrivacy();
      ref.read(formulationProvider.notifier).calculate(request);
      setState(() => _currentStep = 2);
    }
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final int count;
  final int min;

  const _StatusItem({
    required this.label,
    required this.count,
    required this.min,
  });

  @override
  Widget build(BuildContext context) {
    final met = count >= min;
    return Column(
      children: [
        Text(
          '$count/$min',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: met ? AppTheme.primaryGreen : AppTheme.grey600,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.grey200,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.grey600,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.grey600,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
