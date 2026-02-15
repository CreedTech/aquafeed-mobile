import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../../core/widgets/airbnb_toast.dart';
import '../../../core/security/privacy_guard.dart';
import '../../auth/data/auth_repository.dart';
import '../../payment/data/payment_repository.dart';
import '../../payment/presentation/payment_checkout_webview_screen.dart';
import '../data/formulation_repository.dart';
import 'widgets/aura_loader.dart';
import 'widgets/step_indicator.dart';
import 'widgets/strategy_comparison.dart';
import 'widgets/detailed_result_view.dart';
import 'widgets/ingredient_tile.dart';
import 'widgets/standard_tile.dart';
import '../../../shared/paywall_view.dart';

enum _IngredientSortMode { relevance, proteinHigh, priceLow }

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
  bool _showSelectedOnly = false;
  bool _compactIngredientCards = true;
  _IngredientSortMode _ingredientSortMode = _IngredientSortMode.relevance;

  final Set<String> _selectedIngredientIds = {};
  final Map<String, double> _customPrices = {};
  final Map<String, double> _minInclusionPct = {};
  final Map<String, double> _maxInclusionPct = {};
  double _targetWeight = 100;
  String? _selectedStandardId;
  double _overheadCost = 0; // Milling, processing, pelletizing, transport
  String _selectedCategory = 'Fish';
  String? _selectedPoultryType;
  double _unlockFee = 10000;
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadUnlockFee();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _disablePrivacy();
    super.dispose();
  }

  Future<void> _enablePrivacy() async {
    await PrivacyGuard.enable();
  }

  Future<void> _disablePrivacy() async {
    await PrivacyGuard.disable();
  }

  Future<void> _handleUnlock(FormulationResult result) async {
    final formulationId = result.formulationId;
    final strategy = result.strategy;
    if (formulationId == null) return;
    final feeLabel = _currencyFormatter.format(_unlockFee);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Production Mix'),
        content: Text(
          'This will deduct $feeLabel from your wallet to unlock the full production recipe.',
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

    await _attemptUnlock(
      formulationId,
      strategy: strategy,
      allowTopUpFallback: true,
    );
  }

  Future<void> _attemptUnlock(
    String formulationId, {
    required String? strategy,
    required bool allowTopUpFallback,
  }) async {
    try {
      if (!mounted) return;
      AirbnbToast.showInfo(context, 'Unlocking production mix...');

      final unlockedResult = await ref
          .read(formulationProvider.notifier)
          .unlock(formulationId, strategy: strategy);

      if (!mounted) return;
      if (unlockedResult != null) {
        _enablePrivacy();
        AirbnbToast.showSuccess(
          context,
          'Production mix unlocked successfully.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      final parsed = _parseUnlockError(e);

      if (parsed.requiresDeposit && allowTopUpFallback) {
        AirbnbToast.showWarning(
          context,
          parsed.message,
          actionLabel: 'Top up now',
          onAction: () {
            unawaited(
              _showTopUpForUnlockAndRetry(
                formulationId: formulationId,
                strategy: strategy,
                requiredAmount: parsed.requiredAmount,
              ),
            );
          },
        );
        return;
      }

      AirbnbToast.showError(context, parsed.message);
    }
  }

  ({String message, bool requiresDeposit, double requiredAmount})
  _parseUnlockError(Object error) {
    String message = 'Failed to unlock formulation. Please try again.';
    bool requiresDeposit = false;
    double requiredAmount = _unlockFee;

    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final backendMessage = data['message']?.toString();
        final backendError = data['error']?.toString();
        if (backendMessage != null && backendMessage.isNotEmpty) {
          message = backendMessage;
        } else if (backendError != null && backendError.isNotEmpty) {
          message = backendError;
        } else if (error.message != null && error.message!.isNotEmpty) {
          message = error.message!;
        }

        requiresDeposit =
            data['requiresDeposit'] == true ||
            (backendError?.toLowerCase().contains('insufficient') ?? false) ||
            (backendMessage?.toLowerCase().contains('insufficient') ?? false);
        requiredAmount =
            (data['requiredAmount'] as num?)?.toDouble() ?? _unlockFee;
      } else if (error.message != null && error.message!.isNotEmpty) {
        message = error.message!;
      }
    } else {
      final fallback = error.toString().replaceFirst('Exception: ', '').trim();
      if (fallback.isNotEmpty) {
        message = fallback;
        requiresDeposit = fallback.toLowerCase().contains('insufficient');
      }
    }

    return (
      message: message,
      requiresDeposit: requiresDeposit,
      requiredAmount: requiredAmount,
    );
  }

  int _recommendedTopUpAmount(double requiredAmount) {
    final required = requiredAmount <= 0 ? _unlockFee : requiredAmount;
    final buffered = (required * 1.2).ceil();
    if (buffered <= 5000) return 5000;
    if (buffered <= 10000) return 10000;
    return ((buffered + 999) ~/ 1000) * 1000;
  }

  String _normalizePaymentStatus(String? rawStatus) {
    final value = (rawStatus ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'success';
    return value;
  }

  bool _isRetryablePaymentMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('not successful') ||
        normalized.contains('verification failed') ||
        normalized.contains('unable to verify') ||
        normalized.contains('timeout') ||
        normalized.contains('pending') ||
        normalized.contains('processing');
  }

  bool _isTerminalPaymentMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('does not belong') ||
        normalized.contains('missing payment reference') ||
        normalized.contains('unsupported payment currency') ||
        normalized.contains('invalid payment amount') ||
        normalized.contains('unable to determine payment owner');
  }

  Future<void> _showTopUpForUnlockAndRetry({
    required String formulationId,
    required String? strategy,
    required double requiredAmount,
  }) async {
    if (!mounted) return;

    final suggested = _recommendedTopUpAmount(requiredAmount);
    final presets = <int>{5000, 10000, 20000, suggested}.toList()..sort();

    final selectedAmount = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Up to Unlock',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add funds now and we will unlock this mix automatically.',
                  style: TextStyle(color: AppTheme.grey600, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presets
                      .map(
                        (amount) => ChoiceChip(
                          selected: amount == suggested,
                          label: Text(_currencyFormatter.format(amount)),
                          onSelected: (_) => Navigator.pop(context, amount),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedAmount == null) return;
    await _runInlineTopUpForUnlock(
      formulationId: formulationId,
      strategy: strategy,
      topUpAmount: selectedAmount,
    );
  }

  Future<void> _runInlineTopUpForUnlock({
    required String formulationId,
    required String? strategy,
    required int topUpAmount,
  }) async {
    try {
      final paymentService = await ref.read(paymentServiceProvider.future);
      if (!mounted) return;

      AirbnbToast.showInfo(
        context,
        'Opening secure checkout for ${_currencyFormatter.format(topUpAmount)}...',
      );

      final init = await paymentService.initializeTopUp(topUpAmount);
      await paymentService.rememberPendingReference(init.reference);

      if (!mounted) return;
      if (init.authorizationUrl.trim().isEmpty) {
        AirbnbToast.showError(
          context,
          'Invalid checkout link returned by server. Please try again.',
        );
        return;
      }

      final callbackUri = await Navigator.of(context).push<Uri>(
        MaterialPageRoute(
          builder: (_) =>
              PaymentCheckoutWebViewScreen(checkoutUrl: init.authorizationUrl),
        ),
      );

      if (!mounted) return;

      var status = 'pending';
      var reference = init.reference;
      if (callbackUri != null) {
        status = _normalizePaymentStatus(callbackUri.queryParameters['status']);
        reference =
            callbackUri.queryParameters['reference'] ??
            callbackUri.queryParameters['trxref'] ??
            init.reference;
      }

      if (status == 'failed' ||
          status == 'abandoned' ||
          status == 'cancelled' ||
          status == 'error') {
        AirbnbToast.showError(context, 'Payment was not completed.');
        return;
      }

      PaymentVerificationResult? verificationResult;
      const retryDelays = <Duration>[
        Duration(milliseconds: 0),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 2000),
        Duration(milliseconds: 3000),
        Duration(milliseconds: 4500),
      ];

      for (var attempt = 0; attempt < retryDelays.length; attempt++) {
        if (retryDelays[attempt] > Duration.zero) {
          await Future<void>.delayed(retryDelays[attempt]);
        }
        verificationResult = await paymentService.verifyPayment(reference);
        if (verificationResult.success) break;
        if (_isTerminalPaymentMessage(verificationResult.message)) break;
        if (!_isRetryablePaymentMessage(verificationResult.message)) break;
      }

      if (!mounted) return;
      if (verificationResult == null) {
        AirbnbToast.showWarning(
          context,
          'Payment confirmation is pending. Please try unlock again shortly.',
        );
        return;
      }

      if (!verificationResult.success) {
        if (_isRetryablePaymentMessage(verificationResult.message)) {
          AirbnbToast.showWarning(
            context,
            'Payment is processing. Wallet will update automatically.',
          );
        } else {
          AirbnbToast.showError(context, verificationResult.message);
        }
        return;
      }

      AirbnbToast.showSuccess(context, 'Wallet funded. Unlocking your mix...');
      await _attemptUnlock(
        formulationId,
        strategy: strategy,
        allowTopUpFallback: false,
      );
    } catch (e) {
      if (!mounted) return;
      AirbnbToast.showError(
        context,
        'Could not complete payment right now. Please try again.',
      );
    }
  }

  Future<void> _loadUnlockFee() async {
    final fee = await ref.read(formulationProvider.notifier).getUnlockFee();
    if (!mounted) return;
    setState(() => _unlockFee = fee > 0 ? fee : 10000);
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
              ? 'Configure Mix'
              : _currentStep == 1
              ? 'Select Ingredients'
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
                ? _buildConfigStep(standardsAsync)
                : _currentStep == 1
                ? _buildIngredientSelection(ingredientsAsync)
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

        var visibleIngredients = ingredients.where((i) {
          if (_searchQuery.isEmpty) return true;
          return i.name.toLowerCase().contains(_searchQuery);
        }).toList();

        if (_showSelectedOnly) {
          visibleIngredients = visibleIngredients
              .where(
                (ingredient) => _selectedIngredientIds.contains(ingredient.id),
              )
              .toList();
        }

        visibleIngredients.sort((a, b) {
          final aSelected = _selectedIngredientIds.contains(a.id);
          final bSelected = _selectedIngredientIds.contains(b.id);
          if (aSelected != bSelected) return aSelected ? -1 : 1;

          switch (_ingredientSortMode) {
            case _IngredientSortMode.proteinHigh:
              final byProtein = (b.nutrients['protein'] ?? 0).compareTo(
                a.nutrients['protein'] ?? 0,
              );
              return byProtein != 0 ? byProtein : a.name.compareTo(b.name);
            case _IngredientSortMode.priceLow:
              final byPrice = a.defaultPrice.compareTo(b.defaultPrice);
              return byPrice != 0 ? byPrice : a.name.compareTo(b.name);
            case _IngredientSortMode.relevance:
              return a.name.compareTo(b.name);
          }
        });

        final proteins = visibleIngredients
            .where((i) => i.category == 'PROTEIN')
            .toList();
        final energy = visibleIngredients
            .where((i) => i.category == 'CARBOHYDRATE' || i.category == 'FIBER')
            .toList();
        final others = visibleIngredients
            .where(
              (i) =>
                  i.category != 'PROTEIN' &&
                  i.category != 'CARBOHYDRATE' &&
                  i.category != 'FIBER',
            )
            .toList();
        final selectedIngredients =
            ingredients
                .where(
                  (ingredient) =>
                      _selectedIngredientIds.contains(ingredient.id),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search ingredients...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.grey400,
                        ),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.grey400,
                                ),
                              ),
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
                  const SizedBox(width: 8),
                  PopupMenuButton<_IngredientSortMode>(
                    tooltip: 'Sort list',
                    color: Colors.white,
                    icon: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sort_rounded,
                        color: AppTheme.grey600,
                      ),
                    ),
                    onSelected: (value) => setState(() {
                      _ingredientSortMode = value;
                    }),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _IngredientSortMode.relevance,
                        child: Text('Sort by name'),
                      ),
                      PopupMenuItem(
                        value: _IngredientSortMode.proteinHigh,
                        child: Text('Sort by protein'),
                      ),
                      PopupMenuItem(
                        value: _IngredientSortMode.priceLow,
                        child: Text('Sort by price'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _showSelectedOnly,
                      showCheckmark: false,
                      label: Text(
                        _showSelectedOnly ? 'Selected only' : 'All ingredients',
                      ),
                      onSelected: (value) =>
                          setState(() => _showSelectedOnly = value),
                      selectedColor: AppTheme.primaryGreen.withValues(
                        alpha: 0.16,
                      ),
                      backgroundColor: AppTheme.grey100,
                      side: BorderSide(
                        color: _showSelectedOnly
                            ? AppTheme.primaryGreen.withValues(alpha: 0.35)
                            : AppTheme.grey200,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _showSelectedOnly
                            ? AppTheme.primaryGreen
                            : AppTheme.grey600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _compactIngredientCards,
                      showCheckmark: false,
                      label: const Text('Compact cards'),
                      onSelected: (value) =>
                          setState(() => _compactIngredientCards = value),
                      selectedColor: AppTheme.primaryGreen.withValues(
                        alpha: 0.16,
                      ),
                      backgroundColor: AppTheme.grey100,
                      side: BorderSide(
                        color: _compactIngredientCards
                            ? AppTheme.primaryGreen.withValues(alpha: 0.35)
                            : AppTheme.grey200,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _compactIngredientCards
                            ? AppTheme.primaryGreen
                            : AppTheme.grey600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: selectedIngredients.isEmpty
                            ? null
                            : () => _showSelectedIngredientsSheet(ingredients),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(color: AppTheme.grey200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Selected ${selectedIngredients.length}'),
                      ),
                    ),
                    if (selectedIngredients.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 36,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _selectedIngredientIds.clear();
                            _customPrices.clear();
                            _minInclusionPct.clear();
                            _maxInclusionPct.clear();
                          }),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
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
                tabs: [
                  Tab(text: 'Protein (${proteins.length})'),
                  Tab(text: 'Energy (${energy.length})'),
                  Tab(text: 'Others (${others.length})'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, color: AppTheme.grey400, size: 30),
            const SizedBox(height: 8),
            Text(
              'No ingredients in this category',
              style: TextStyle(color: AppTheme.grey600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: ingredients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final ing = ingredients[index];
        return IngredientTile(
          ingredient: ing,
          isSelected: _selectedIngredientIds.contains(ing.id),
          compact: _compactIngredientCards,
          customPrice: _customPrices[ing.id],
          onToggle: () => setState(() {
            if (_selectedIngredientIds.contains(ing.id)) {
              _selectedIngredientIds.remove(ing.id);
              _customPrices.remove(ing.id);
              _minInclusionPct.remove(ing.id);
              _maxInclusionPct.remove(ing.id);
            } else {
              _selectedIngredientIds.add(ing.id);
            }
          }),
          minInclusionPct: _minInclusionPct[ing.id],
          maxInclusionPct: _maxInclusionPct[ing.id],
          onPriceChanged: (price) => setState(() {
            if (price != null && price != ing.defaultPrice) {
              _customPrices[ing.id] = price;
            } else {
              _customPrices.remove(ing.id);
            }
          }),
          onConstraintsChanged: (minPct, maxPct) => setState(() {
            if (minPct != null) {
              _minInclusionPct[ing.id] = minPct;
            } else {
              _minInclusionPct.remove(ing.id);
            }
            if (maxPct != null) {
              _maxInclusionPct[ing.id] = maxPct;
            } else {
              _maxInclusionPct.remove(ing.id);
            }
          }),
        );
      },
    );
  }

  void _showSelectedIngredientsSheet(List<Ingredient> allIngredients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final selectedIngredients =
                allIngredients
                    .where((i) => _selectedIngredientIds.contains(i.id))
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                      child: Row(
                        children: [
                          Text(
                            'Selected (${selectedIngredients.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (selectedIngredients.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedIngredientIds.clear();
                                  _customPrices.clear();
                                  _minInclusionPct.clear();
                                  _maxInclusionPct.clear();
                                });
                                sheetSetState(() {});
                              },
                              child: const Text('Clear all'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: selectedIngredients.isEmpty
                          ? const Center(
                              child: Text(
                                'No ingredients selected',
                                style: TextStyle(color: AppTheme.grey600),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: selectedIngredients.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final ingredient = selectedIngredients[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  title: Text(
                                    ingredient.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    ingredient.category
                                        .replaceAll('_', ' ')
                                        .toLowerCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.grey600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () {
                                      setState(() {
                                        _selectedIngredientIds.remove(
                                          ingredient.id,
                                        );
                                        _customPrices.remove(ingredient.id);
                                        _minInclusionPct.remove(ingredient.id);
                                        _maxInclusionPct.remove(ingredient.id);
                                      });
                                      sheetSetState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: AppTheme.errorRed,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
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
                label: 'Fish',
                icon: Icons.set_meal_outlined,
                isSelected: _selectedCategory == 'Fish',
                onTap: () => setState(() {
                  _selectedCategory = 'Fish';
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
          _selectedCategory == 'Fish'
              ? 'Select Fish Stage'
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
                      ((_selectedCategory == 'Fish' &&
                              (s.feedCategory == 'Catfish' ||
                                  (s.feedType ?? '').toLowerCase() ==
                                      'fish')) ||
                          (_selectedCategory == 'Poultry' &&
                              s.feedCategory == 'Poultry')) &&
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

              const SizedBox(height: 24),

              // Selected result details
              DetailedResultView(result: result),
              const SizedBox(height: 24),

              // Action buttons
              if (!result.isUnlocked && result.formulationId != null) ...[
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
                            'Unlock full recipe for ${_currencyFormatter.format(_unlockFee)}',
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

  FormulationRequest _buildCurrentRequest() {
    return FormulationRequest(
      targetWeightKg: _targetWeight,
      standardId: _selectedStandardId!,
      selectedIngredients: _selectedIngredientIds
          .map(
            (id) => SelectedIngredient(
              ingredientId: id,
              customPrice: _customPrices[id],
              minInclusionPct: _minInclusionPct[id],
              maxInclusionPct: _maxInclusionPct[id],
            ),
          )
          .toList(),
      overheadCost: _overheadCost,
    );
  }

  Future<void> _previewRecommendedAction(RecommendedAction action) async {
    if (_selectedStandardId == null) return;
    final request = _buildCurrentRequest();

    try {
      final preview = await ref
          .read(formulationProvider.notifier)
          .previewFix(originalRequest: request, action: action);

      if (!mounted) return;
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action.description,
                style: const TextStyle(
                  color: AppTheme.grey600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Cost Delta: ${preview.estimatedCostDelta?.toStringAsFixed(2) ?? '--'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estimated Quality Delta: ${preview.estimatedComplianceDelta?.toStringAsFixed(2) ?? '--'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preview Options: ${preview.options.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Use This Fix'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (accepted == true) {
        ref.read(formulationProvider.notifier).usePreviewResult(preview);
        _enablePrivacy();
        setState(() {
          _currentStep = 2;
          _selectedOptionIndex = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is InfeasibleFormulationException
          ? e.suggestion
          : 'Unable to apply this fix preview.';
      AirbnbToast.showError(context, message);
    }
  }

  Widget _buildErrorState(Object error) {
    if (error is PaymentRequiredException) {
      return PaywallView(
        featureName: 'Feed Formulation',
        description: error.message,
        icon: Icons.lock_outline,
      );
    }

    if (error is InfeasibleFormulationException) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We Could Not Meet Your Targets Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error.message,
              style: const TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 8),
            Text(
              error.suggestion,
              style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
            ),
            if (error.violations.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Detected constraints',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...error.violations
                  .take(4)
                  .map(
                    (violation) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '• ${violation.message}',
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
            ],
            if (error.recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'One-tap fixes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...error.recommendedActions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _previewRecommendedAction(action),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(action.label),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(formulationProvider.notifier).reset();
                  setState(() => _currentStep = 0);
                },
                child: const Text('Edit Ingredients Manually'),
              ),
            ),
          ],
        ),
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
        ? _selectedStandardId != null
        : _selectedIngredientIds.length >= 5 &&
              proteinCount > 0 &&
              energyCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
            if (_currentStep == 1) ...[
              if (warnings.isNotEmpty && _selectedIngredientIds.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.grey600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warnings.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ),
                      if (warnings.length > 1)
                        Text(
                          '+${warnings.length - 1}',
                          style: const TextStyle(
                            color: AppTheme.grey600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
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
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canProceed ? _handleNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.grey200,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
      final request = _buildCurrentRequest();

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: met
            ? AppTheme.primaryGreen.withValues(alpha: 0.1)
            : AppTheme.grey100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: met
              ? AppTheme.primaryGreen.withValues(alpha: 0.35)
              : AppTheme.grey200,
        ),
      ),
      child: Text(
        '$label $count/$min',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: met ? AppTheme.primaryGreen : AppTheme.grey600,
        ),
      ),
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
