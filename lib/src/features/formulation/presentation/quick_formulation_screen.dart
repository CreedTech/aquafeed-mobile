import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../../core/widgets/airbnb_toast.dart';
import '../../../shared/paywall_view.dart';
import '../../auth/data/auth_repository.dart';
import '../../payment/data/payment_repository.dart';
import '../../payment/presentation/payment_checkout_webview_screen.dart';
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
  double _unlockFee = 10000;

  @override
  void initState() {
    super.initState();
    _loadUnlockFee();
  }

  Future<void> _handleUnlock(FormulationResult result) async {
    final formulationId = result.formulationId;
    final strategy = result.strategy;
    if (formulationId == null) return;
    final feeLabel = _formatter.format(_unlockFee);

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
                          label: Text(_formatter.format(amount)),
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
        'Opening secure checkout for ${_formatter.format(topUpAmount)}...',
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
    } catch (_) {
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
                unlockFeeLabel: _formatter.format(_unlockFee),
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
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        const minWeight = 10.0;
                        const maxWeight = 1000.0;
                        const divisions = 99;

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
    final selectedStandardId = _selectedStandardId;
    if (selectedStandardId == null) return;

    final standards = ref.read(feedStandardsProvider).value ?? const <FeedStandard>[];
    FeedStandard? selectedStandard;
    for (final standard in standards) {
      if (standard.id == selectedStandardId) {
        selectedStandard = standard;
        break;
      }
    }
    if (selectedStandard == null) {
      AirbnbToast.showWarning(
        context,
        'Selected standard is no longer available. Please choose another standard.',
      );
      return;
    }

    final templateIsPoultry = template.feedCategory.toLowerCase() == 'poultry';
    final standardIsPoultry =
        selectedStandard.feedCategory.toLowerCase() == 'poultry' ||
        (selectedStandard.feedType ?? '').toLowerCase() == 'poultry';

    if (templateIsPoultry != standardIsPoultry) {
      AirbnbToast.showWarning(
        context,
        'Selected template and standard do not match. Please pick a matching standard.',
      );
      return;
    }

    if (templateIsPoultry &&
        template.poultryType != null &&
        selectedStandard.poultryType != null &&
        template.poultryType!.toLowerCase() !=
            selectedStandard.poultryType!.toLowerCase()) {
      AirbnbToast.showWarning(
        context,
        'Template poultry type does not match the selected standard.',
      );
      return;
    }

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
      AirbnbToast.showWarning(
        context,
        'Not enough ingredients matched. Try manual selection.',
      );
      return;
    }

    ref
        .read(formulationProvider.notifier)
        .calculate(
          FormulationRequest(
            targetWeightKg: _targetWeight,
            standardId: selectedStandardId,
            selectedIngredients: selected,
          ),
        );
  }
}

class _ResultView extends StatelessWidget {
  final FormulationResult result;
  final NumberFormat formatter;
  final String unlockFeeLabel;
  final VoidCallback onReset;
  final VoidCallback onUnlock;

  const _ResultView({
    required this.result,
    required this.formatter,
    required this.unlockFeeLabel,
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
                    Text(
                      'Unlock Production Mix ($unlockFeeLabel)',
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
