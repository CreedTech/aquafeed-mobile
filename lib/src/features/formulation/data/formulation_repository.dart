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

  FeedStandard({
    required this.id,
    required this.name,
    required this.brand,
    required this.stage,
    this.pelletSize,
  });

  factory FeedStandard.fromJson(Map<String, dynamic> json) {
    return FeedStandard(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      stage: json['stage'] ?? '',
      pelletSize: json['pelletSize'],
    );
  }
}

/// Formulation request
class FormulationRequest {
  final double targetWeightKg;
  final String standardId;
  final List<SelectedIngredient> selectedIngredients;
  final double overheadCost; // Milling, processing, transport

  FormulationRequest({
    required this.targetWeightKg,
    required this.standardId,
    required this.selectedIngredients,
    this.overheadCost = 0,
  });

  Map<String, dynamic> toJson() => {
    'targetWeightKg': targetWeightKg,
    'standardId': standardId,
    'selectedIngredients': selectedIngredients.map((i) => i.toJson()).toList(),
    'overheadCost': overheadCost,
  };
}

class SelectedIngredient {
  final String ingredientId;
  final double? customPrice;

  SelectedIngredient({required this.ingredientId, this.customPrice});

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    if (customPrice != null) 'customPrice': customPrice,
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

/// Formulation notifier for managing the formulation flow
@riverpod
class FormulationNotifier extends _$FormulationNotifier {
  @override
  AsyncValue<List<FormulationResult>?> build() => const AsyncData(null);

  Future<void> calculate(FormulationRequest request) async {
    state = const AsyncLoading();

    try {
      final dio = await ref.watch(dioProvider.future);
      final response = await dio.post(
        '/formulations/calculate',
        data: request.toJson(),
      );

      if (response.data['status'] == 'infeasible') {
        // Pass both message and suggestion
        final msg = response.data['message'];
        final suggestion = response.data['suggestion'];
        throw Exception('$msg\n\nTip: $suggestion');
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
      state = AsyncError(e.toString(), stack);
    }
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

  void reset() {
    state = const AsyncData(null);
  }

  bool canCreateFormula() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    return user.canCreateFormula;
  }
}
