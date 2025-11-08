import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/networking/dio_provider.dart';
import '../../../core/utils/error_helper.dart';
import '../../dashboard/data/dashboard_repository.dart';

part 'financials_repository.g.dart';

/// Expense model matching backend
class Expense {
  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime date;
  final String? receiptUrl;

  Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.receiptUrl,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['_id'] ?? '',
      category: json['category'] ?? 'Other',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      receiptUrl: json['receiptUrl'],
    );
  }
}

/// Revenue model matching backend (type, quantity, pricePerUnit, buyer)
class Revenue {
  final String id;
  final String type; // 'Fish Sales', 'Fingerling Sales', 'Other'
  final int quantity;
  final double pricePerUnit;
  final double totalAmount;
  final String? buyer;
  final DateTime date;

  Revenue({
    required this.id,
    required this.type,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalAmount,
    this.buyer,
    required this.date,
  });

  factory Revenue.fromJson(Map<String, dynamic> json) {
    return Revenue(
      id: json['_id'] ?? '',
      type: json['type'] ?? 'Other',
      quantity: json['quantity'] ?? 0,
      pricePerUnit: (json['pricePerUnit'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      buyer: json['buyer'],
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

@riverpod
class Expenses extends _$Expenses {
  @override
  FutureOr<List<Expense>> build() async {
    return fetchExpenses();
  }

  Future<List<Expense>> fetchExpenses() async {
    try {
      final dio = await ref.watch(dioProvider.future);
      final response = await dio.get('/financials/expenses');
      final data = response.data['data'] as List? ?? [];
      return data.map((e) => Expense.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  /// Add expense - matches backend contract
  Future<void> addExpense({
    required String category,
    required String description,
    required double amount,
    DateTime? date,
  }) async {
    try {
      final dio = await ref.watch(dioProvider.future);
      await dio.post(
        '/financials/expenses',
        data: {
          'category': category,
          'description': description,
          'amount': amount,
          'date': (date ?? DateTime.now()).toIso8601String(),
        },
      );
      ref.invalidateSelf();
      ref.invalidate(dashboardRepositoryProvider);
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }
}

@riverpod
class Revenues extends _$Revenues {
  @override
  FutureOr<List<Revenue>> build() async {
    return fetchRevenues();
  }

  Future<List<Revenue>> fetchRevenues() async {
    try {
      final dio = await ref.watch(dioProvider.future);
      final response = await dio.get('/financials/revenue');
      final data = response.data['data'] as List? ?? [];
      return data.map((r) => Revenue.fromJson(r)).toList();
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  /// Add revenue - matches backend contract (type, quantity, pricePerUnit, buyer)
  Future<void> addRevenue({
    required String type, // 'Fish Sales', 'Fingerling Sales', 'Other'
    required int quantity,
    required double pricePerUnit,
    String? buyer,
    DateTime? date,
  }) async {
    try {
      final dio = await ref.watch(dioProvider.future);
      await dio.post(
        '/financials/revenue',
        data: {
          'type': type,
          'quantity': quantity,
          'pricePerUnit': pricePerUnit,
          if (buyer != null && buyer.isNotEmpty) 'buyer': buyer,
          'date': (date ?? DateTime.now()).toIso8601String(),
        },
      );
      ref.invalidateSelf();
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }
}
