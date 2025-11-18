import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/networking/dio_provider.dart';
import '../../../core/utils/error_helper.dart';
import '../../dashboard/data/dashboard_repository.dart';

part 'inventory_repository.g.dart';

class InventoryItem {
  final String id;
  final String ingredientId;
  final String ingredientName;
  final String category;
  final double currentQuantity; // currentStockKg from backend
  final String unit;
  final double unitPrice; // userLocalPrice from backend
  final double reorderLevel; // lowStockThreshold from backend
  final bool isLowStock;
  final double value;

  InventoryItem({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.category,
    required this.currentQuantity,
    required this.unit,
    required this.unitPrice,
    required this.reorderLevel,
    required this.isLowStock,
    required this.value,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    // Handle populated ingredientId object
    final ingData = json['ingredientId'];
    String ingId = '';
    String ingName = 'Unknown';
    String ingCategory = 'OTHER';

    if (ingData is Map) {
      ingId = ingData['_id']?.toString() ?? '';
      ingName = ingData['name'] ?? 'Unknown';
      ingCategory = ingData['category'] ?? 'OTHER';
    } else if (ingData is String) {
      ingId = ingData;
    }

    return InventoryItem(
      id: json['_id'] ?? '',
      ingredientId: ingId,
      ingredientName: ingName,
      category: ingCategory,
      currentQuantity: (json['currentStockKg'] ?? json['currentQuantity'] ?? 0)
          .toDouble(),
      unit: 'kg',
      unitPrice: (json['userLocalPrice'] ?? json['unitPrice'] ?? 0).toDouble(),
      reorderLevel: (json['lowStockThreshold'] ?? json['reorderLevel'] ?? 50)
          .toDouble(),
      isLowStock: json['isLowStock'] ?? false,
      value: (json['value'] ?? 0).toDouble(),
    );
  }
}

@riverpod
class InventoryRepository extends _$InventoryRepository {
  @override
  FutureOr<List<InventoryItem>> build() async {
    return fetchInventory();
  }

  Future<List<InventoryItem>> fetchInventory() async {
    try {
      final dio = await ref.watch(dioProvider.future);
      final response = await dio.get('/inventory');
      final data = response.data['data'] as List? ?? [];
      return data.map((item) => InventoryItem.fromJson(item)).toList();
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  /// Add stock - requires ingredientId (from ingredients list)
  Future<void> addStock({
    required String ingredientId,
    required double quantityKg,
    required double pricePerKg,
  }) async {
    try {
      final dio = await ref.watch(dioProvider.future);
      await dio.post(
        '/inventory',
        data: {
          'ingredientId': ingredientId,
          'quantityKg': quantityKg,
          'pricePerKg': pricePerKg,
        },
      );
      ref.invalidateSelf();
      ref.invalidate(dashboardRepositoryProvider);
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  /// Update stock quantity (for corrections/wastage)
  Future<void> updateStock(
    String itemId, {
    double? currentQuantity,
    double? reorderLevel,
  }) async {
    try {
      final dio = await ref.watch(dioProvider.future);
      await dio.patch(
        '/inventory/$itemId',
        data: {
          if (currentQuantity != null) 'currentStockKg': currentQuantity,
          if (reorderLevel != null) 'lowStockThreshold': reorderLevel,
        },
      );
      ref.invalidateSelf();
      ref.invalidate(dashboardRepositoryProvider);
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  /// Deduct stock (usage)
  Future<void> deductStock({
    required String ingredientId,
    required double quantityKg,
  }) async {
    try {
      final dio = await ref.watch(dioProvider.future);
      await dio.post(
        '/inventory/deduct',
        data: {'ingredientId': ingredientId, 'quantityKg': quantityKg},
      );
      ref.invalidateSelf();
      ref.invalidate(dashboardRepositoryProvider);
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }
}
