import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import '../../../core/networking/dio_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';

part 'formulation_repository.g.dart';

/// Exception thrown when payment is required for access
class PaymentRequiredException implements Exception {
  final String message;
  final double amount;

  PaymentRequiredException({required this.message, required this.amount});

  @override
  String toString() => message;
}

class ConstraintViolation {
  final String constraintId;
  final String type;
  final String? nutrient;
  final double current;
  final double required;
  final double gap;
  final String unit;
  final String message;

  ConstraintViolation({
    required this.constraintId,
    required this.type,
    this.nutrient,
    required this.current,
    required this.required,
    required this.gap,
    required this.unit,
    required this.message,
  });

  factory ConstraintViolation.fromJson(Map<String, dynamic> json) {
    return ConstraintViolation(
      constraintId: json['constraintId'] ?? '',
      type: json['type'] ?? '',
      nutrient: json['nutrient'],
      current: (json['current'] ?? 0).toDouble(),
      required: (json['required'] ?? 0).toDouble(),
      gap: (json['gap'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class RecommendedAction {
  final String actionType;
  final String label;
  final String description;
  final Map<String, dynamic> patch;
  final double estimatedCostDelta;
  final double estimatedComplianceDelta;
  final double confidence;

  RecommendedAction({
    required this.actionType,
    required this.label,
    required this.description,
    required this.patch,
    required this.estimatedCostDelta,
    required this.estimatedComplianceDelta,
    required this.confidence,
  });

  factory RecommendedAction.fromJson(Map<String, dynamic> json) {
    return RecommendedAction(
      actionType: json['actionType'] ?? '',
      label: json['label'] ?? '',
      description: json['description'] ?? '',
      patch: Map<String, dynamic>.from(json['patch'] ?? {}),
      estimatedCostDelta: (json['estimatedCostDelta'] ?? 0).toDouble(),
      estimatedComplianceDelta: (json['estimatedComplianceDelta'] ?? 0)
          .toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class InfeasibleFormulationException implements Exception {
  final String message;
  final String suggestion;
  final List<ConstraintViolation> violations;
  final List<RecommendedAction> recommendedActions;

  InfeasibleFormulationException({
    required this.message,
    required this.suggestion,
    required this.violations,
    required this.recommendedActions,
  });

  @override
  String toString() => message;
}

class PreviewResult {
  final bool feasible;
  final FormulationResult? bestOption;
  final List<FormulationResult> options;
  final double? estimatedCostDelta;
  final double? estimatedComplianceDelta;

  PreviewResult({
    required this.feasible,
    this.bestOption,
    required this.options,
    this.estimatedCostDelta,
    this.estimatedComplianceDelta,
  });

  factory PreviewResult.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'] as List? ?? [];
    final parsedOptions = optionsJson
        .map((o) => FormulationResult.fromJson(Map<String, dynamic>.from(o)))
        .toList();
    final bestOptionJson = json['bestOption'];
    return PreviewResult(
      feasible: json['feasible'] ?? false,
      bestOption: bestOptionJson != null
          ? FormulationResult.fromJson(
              Map<String, dynamic>.from(bestOptionJson),
            )
          : null,
      options: parsedOptions,
      estimatedCostDelta: json['estimatedCostDelta']?.toDouble(),
      estimatedComplianceDelta: json['estimatedComplianceDelta']?.toDouble(),
    );
  }
}

/// Ingredient model
class Ingredient {
  final String id;
  final String name;
  final String category;
  final double defaultPrice;
  final String unit;
  final double? bagWeight;
  final Map<String, double> nutrients;

  Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultPrice,
    required this.unit,
    this.bagWeight,
    required this.nutrients,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'OTHER',
      defaultPrice: (json['defaultPrice'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'kg',
      bagWeight: json['bagWeight']?.toDouble(),
      nutrients: _parseNutrients(json['nutrients']),
    );
  }

  static Map<String, double> _parseNutrients(dynamic nutrientsData) {
    if (nutrientsData == null) return {};
    if (nutrientsData is! Map) return {};
    return Map<String, double>.from(
      nutrientsData.map((k, v) => MapEntry(k.toString(), (v ?? 0).toDouble())),
    );
  }
}

/// Feed Standard model
class FeedStandard {
  final String id;
  final String name;
  final String brand;
  final String stage;
  final String? pelletSize;
  final String feedCategory;
  final String? feedType;
  final String? fishSubtype;
  final String? poultryType;
  final int tolerance;

  FeedStandard({
    required this.id,
    required this.name,
    required this.brand,
    required this.stage,
    this.pelletSize,
    required this.feedCategory,
    this.feedType,
    this.fishSubtype,
    this.poultryType,
    required this.tolerance,
  });

  factory FeedStandard.fromJson(Map<String, dynamic> json) {
    return FeedStandard(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      stage: json['stage'] ?? '',
      pelletSize: json['pelletSize'],
      feedCategory:
          json['feedCategory'] ??
          ((json['feedType'] == 'poultry') ? 'Poultry' : 'Catfish'),
      feedType: json['feedType'],
      fishSubtype: json['fishSubtype'],
      poultryType: json['poultryType'],
      tolerance: json['tolerance'] ?? 2,
    );
  }
}

/// Feed Template model for Quick Mix
class FeedTemplate {
  final String id;
  final String name;
  final String description;
  final String feedCategory;
  final String? poultryType;
  final List<String> ingredientNames;

  FeedTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.feedCategory,
    this.poultryType,
    required this.ingredientNames,
  });

  factory FeedTemplate.fromJson(Map<String, dynamic> json) {
    return FeedTemplate(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      feedCategory: json['feedCategory'] ?? 'Catfish',
      poultryType: json['poultryType'],
      ingredientNames: List<String>.from(json['ingredientNames'] ?? []),
    );
  }
}

/// Formulation request
class FormulationRequest {
  final double targetWeightKg;
  final String standardId;
  final List<SelectedIngredient> selectedIngredients;
  final double overheadCost; // Milling, processing, transport
  final Map<String, Map<String, double>>? targetOverrides;

  FormulationRequest({
    required this.targetWeightKg,
    required this.standardId,
    required this.selectedIngredients,
    this.overheadCost = 0,
    this.targetOverrides,
  });

  Map<String, dynamic> toJson() => {
    'targetWeightKg': targetWeightKg,
    'standardId': standardId,
    'selectedIngredients': selectedIngredients.map((i) => i.toJson()).toList(),
    'overheadCost': overheadCost,
    if (targetOverrides != null) 'targetOverrides': targetOverrides,
  };
}

class SelectedIngredient {
  final String ingredientId;
  final double? customPrice;
  final double? minInclusionPct;
  final double? maxInclusionPct;
  final String? alternativeIngredientId;

  SelectedIngredient({
    required this.ingredientId,
    this.customPrice,
    this.minInclusionPct,
    this.maxInclusionPct,
    this.alternativeIngredientId,
  });

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    if (customPrice != null) 'customPrice': customPrice,
    if (minInclusionPct != null) 'minInclusionPct': minInclusionPct,
    if (maxInclusionPct != null) 'maxInclusionPct': maxInclusionPct,
    if (alternativeIngredientId != null)
      'alternativeIngredientId': alternativeIngredientId,
  };
}

/// Nutrient status for per-nutrient compliance display
class NutrientStatus {
  final String nutrient;
  final double actual;
  final double? targetMin;
  final double? targetMax;
  final double targetValue;
  final double deviationPercent;
  final String status; // 'Below', 'Within', 'Above'

  NutrientStatus({
    required this.nutrient,
    required this.actual,
    this.targetMin,
    this.targetMax,
    required this.targetValue,
    required this.deviationPercent,
    required this.status,
  });

  factory NutrientStatus.fromJson(Map<String, dynamic> json) {
    final target = json['target'];
    double? targetMin;
    double? targetMax;
    double targetValue;

    if (target is Map) {
      targetMin = (target['min'] ?? 0).toDouble();
      targetMax = (target['max'] ?? 0).toDouble();
      targetValue = ((targetMin ?? 0) + (targetMax ?? 0)) / 2;
    } else {
      targetValue = (target ?? 0).toDouble();
    }

    return NutrientStatus(
      nutrient: json['nutrient'] ?? '',
      actual: (json['actual'] ?? 0).toDouble(),
      targetMin: targetMin,
      targetMax: targetMax,
      targetValue: targetValue,
      deviationPercent: (json['deviationPercent'] ?? 0).toDouble(),
      status: json['status'] ?? 'Within',
    );
  }
}

/// Formulation result
class FormulationResult {
  final String? strategy; // LEAST_COST, BALANCED, PREMIUM
  final String? formulationId;
  final String complianceColor; // GREEN, YELLOW, RED
  final double qualityMatch;
  final double totalCost;
  final double costPerKg;
  final Map<String, double> actualNutrients;
  final List<NutrientStatus> nutrientStatuses; // Per-nutrient comparison
  final bool isUnlocked;
  final bool isDemo;
  final double? effectiveWeightKg;
  final List<IngredientUsed>? ingredientsUsed;

  FormulationResult({
    this.strategy,
    this.formulationId,
    required this.complianceColor,
    required this.qualityMatch,
    required this.totalCost,
    required this.costPerKg,
    required this.actualNutrients,
    required this.nutrientStatuses,
    required this.isUnlocked,
    this.isDemo = false,
    this.effectiveWeightKg,
    this.ingredientsUsed,
  });

  factory FormulationResult.fromJson(Map<String, dynamic> json) {
    return FormulationResult(
      strategy: json['strategy'],
      formulationId: json['formulationId'],
      complianceColor: json['complianceColor'] ?? 'YELLOW',
      qualityMatch: (json['qualityMatch'] ?? 0).toDouble(),
      totalCost: (json['totalCost'] ?? 0).toDouble(),
      costPerKg: (json['costPerKg'] ?? 0).toDouble(),
      actualNutrients: Ingredient._parseNutrients(json['actualNutrients']),
      nutrientStatuses: json['nutrientStatuses'] != null
          ? (json['nutrientStatuses'] as List)
                .map((s) => NutrientStatus.fromJson(s))
                .toList()
          : [],
      isUnlocked: json['isUnlocked'] ?? false,
      isDemo: json['isDemo'] ?? false,
      effectiveWeightKg: json['effectiveWeightKg']?.toDouble(),
      ingredientsUsed: json['recipe'] != null
          ? (json['recipe'] as List)
                .map((i) => IngredientUsed.fromJson(i))
                .toList()
          : (json['ingredientsUsed'] != null
                ? (json['ingredientsUsed'] as List)
                      .map((i) => IngredientUsed.fromJson(i))
                      .toList()
                : null),
    );
  }
}

class IngredientUsed {
  final String name;
  final double qtyKg;
  final int bags;
  final double priceAtMoment;
  final bool isAutoCalculated; // True for Vitamin C (400mg/kg)

  IngredientUsed({
    required this.name,
    required this.qtyKg,
    required this.bags,
    required this.priceAtMoment,
    this.isAutoCalculated = false,
  });

  factory IngredientUsed.fromJson(Map<String, dynamic> json) {
    return IngredientUsed(
      name: json['name'] ?? '',
      qtyKg: (json['qtyKg'] ?? 0).toDouble(),
      bags: json['bags'] ?? 0,
      priceAtMoment: (json['priceAtMoment'] ?? 0).toDouble(),
      isAutoCalculated: json['isAutoCalculated'] ?? false,
    );
  }
}

/// Ingredients provider
@riverpod
Future<List<Ingredient>> ingredients(Ref ref) async {
  final dio = await ref.watch(dioProvider.future);
  final response = await dio.get('/ingredients');
  final data = response.data['ingredients'] as List? ?? [];
  return data.map((i) => Ingredient.fromJson(i)).toList();
}

/// Feed standards provider
@riverpod
Future<List<FeedStandard>> feedStandards(Ref ref) async {
  final dio = await ref.watch(dioProvider.future);
  final response = await dio.get('/standards');
  final data = response.data['standards'] as List? ?? [];
  return data.map((s) => FeedStandard.fromJson(s)).toList();
}

/// Feed templates provider
@riverpod
Future<List<FeedTemplate>> feedTemplates(Ref ref) async {
  final dio = await ref.watch(dioProvider.future);
  final response = await dio.get('/templates');
  final data = response.data as List? ?? [];
  return data.map((t) => FeedTemplate.fromJson(t)).toList();
}

/// Formulation notifier for managing the formulation flow
@riverpod
class FormulationNotifier extends _$FormulationNotifier {
  FormulationRequest? _lastRequest;

  FormulationRequest? get lastRequest => _lastRequest;

  @override
  AsyncValue<List<FormulationResult>?> build() => const AsyncData(null);

  Future<void> calculate(FormulationRequest request) async {
    state = const AsyncLoading();
    _lastRequest = request;

    try {
      final dio = await ref.watch(dioProvider.future);
      final response = await dio.post(
        '/formulations/calculate',
        data: request.toJson(),
      );

      if (response.data['status'] == 'infeasible') {
        final msg = response.data['message'] ?? 'Formulation infeasible';
        final suggestion = response.data['suggestion'] ?? '';
        final violationsJson = response.data['violations'] as List? ?? [];
        final actionsJson = response.data['recommendedActions'] as List? ?? [];
        throw InfeasibleFormulationException(
          message: msg,
          suggestion: suggestion,
          violations: violationsJson
              .map(
                (v) =>
                    ConstraintViolation.fromJson(Map<String, dynamic>.from(v)),
              )
              .toList(),
          recommendedActions: actionsJson
              .map(
                (a) => RecommendedAction.fromJson(Map<String, dynamic>.from(a)),
              )
              .toList(),
        );
      }

      final List<dynamic> optionsJson = response.data['options'] ?? [];
      final bool isDemo = response.data['isDemo'] ?? false;
      final double? effectiveWeightKg = response.data['effectiveWeightKg']
          ?.toDouble();

      final results = optionsJson.map((o) {
        final map = Map<String, dynamic>.from(o);
        map['isDemo'] = isDemo;
        map['effectiveWeightKg'] = effectiveWeightKg;
        map['formulationId'] = response.data['formulationId'];
        return FormulationResult.fromJson(map);
      }).toList();

      state = AsyncData(results);
    } on DioException catch (e, stack) {
      // Handle 403 - Payment Required
      if (e.response?.statusCode == 403) {
        final data = e.response?.data;
        if (data is Map && data['requiresPayment'] == true) {
          state = AsyncError(
            PaymentRequiredException(
              message: data['message'] ?? 'Payment required',
              amount: (data['amount'] ?? 10000).toDouble(),
            ),
            stack,
          );
          return;
        }
      }

      // Handle other errors
      String errorMessage = e.toString();
      final data = e.response?.data;
      if (data is Map && data.containsKey('message')) {
        errorMessage = data['message'];
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      state = AsyncError(errorMessage, stack);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<PreviewResult> previewFix({
    required FormulationRequest originalRequest,
    required RecommendedAction action,
  }) async {
    final dio = await ref.watch(dioProvider.future);
    final response = await dio.post(
      '/formulations/preview-fix',
      data: {
        'originalRequest': originalRequest.toJson(),
        'action': {'actionType': action.actionType, 'patch': action.patch},
      },
    );

    if (response.data['status'] == 'preview_infeasible' ||
        response.data['status'] == 'infeasible') {
      final msg = response.data['message'] ?? 'Still infeasible';
      final suggestion = response.data['suggestion'] ?? '';
      final violationsJson = response.data['violations'] as List? ?? [];
      final actionsJson = response.data['recommendedActions'] as List? ?? [];
      throw InfeasibleFormulationException(
        message: msg,
        suggestion: suggestion,
        violations: violationsJson
            .map(
              (v) => ConstraintViolation.fromJson(Map<String, dynamic>.from(v)),
            )
            .toList(),
        recommendedActions: actionsJson
            .map(
              (a) => RecommendedAction.fromJson(Map<String, dynamic>.from(a)),
            )
            .toList(),
      );
    }

    final previewJson = Map<String, dynamic>.from(
      response.data['preview'] ?? {},
    );
    return PreviewResult.fromJson(previewJson);
  }

  Future<FormulationResult?> unlock(String formulationId) async {
    final dio = await ref.watch(dioProvider.future);
    final response = await dio.post('/formulations/$formulationId/unlock');
    final unlockedResult = FormulationResult.fromJson(
      response.data['formulation'],
    );

    // Update local state if it exists
    final currentResults = state.value;
    if (currentResults != null) {
      final updatedResults = currentResults.map((r) {
        if (r.formulationId == formulationId) {
          // If the backend returns a partial result, we merge or replace
          // In our case, the backend returns the full unlocked recipe
          return unlockedResult;
        }
        return r;
      }).toList();
      state = AsyncData(updatedResults);
    }

    ref.invalidate(dashboardRepositoryProvider);
    return unlockedResult;
  }

  Future<double> getUnlockFee() async {
    try {
      final dio = await ref.watch(dioProvider.future);
      final response = await dio.get('/formulations/unlock-fee');
      return (response.data['formulationFee'] ?? 10000).toDouble();
    } catch (_) {
      return 10000;
    }
  }

  void usePreviewResult(PreviewResult preview) {
    if (preview.options.isEmpty) return;
    state = AsyncData(preview.options);
  }

  void reset() {
    _lastRequest = null;
    state = const AsyncData(null);
  }

  bool canCreateFormula() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    return user.canCreateFormula;
  }
}
