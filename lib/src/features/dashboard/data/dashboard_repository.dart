import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/networking/dio_provider.dart';
import '../../../core/utils/error_helper.dart';
import '../../auth/data/auth_repository.dart';

part 'dashboard_repository.g.dart';

/// Aggregated data for the Dashboard Home Tab
class DashboardData {
  final List<PondSummary> ponds;
  final InventorySummary inventory;
  final FinancialSummary financials;
  final List<MixSummary> mixes;

  DashboardData({
    required this.ponds,
    required this.inventory,
    required this.financials,
    required this.mixes,
  });

  /// Empty dashboard for when user is not authenticated
  factory DashboardData.empty() => DashboardData(
    ponds: [],
    inventory: InventorySummary.empty(),
    financials: FinancialSummary.empty(),
    mixes: [],
  );

  int get totalMixes => mixes.length;

  int get unlockedMixes => mixes.where((mix) => mix.isUnlocked).length;

  int get compliantMixes =>
      mixes.where((mix) => mix.complianceColor.toLowerCase() == 'green').length;

  double get averageQualityMatch {
    if (mixes.isEmpty) return 0;
    final total = mixes.fold<double>(0, (sum, mix) => sum + mix.qualityMatch);
    return total / mixes.length;
  }
}

class MixSummary {
  final String id;
  final String title;
  final String complianceColor;
  final double qualityMatch;
  final double totalCost;
  final double costPerKg;
  final bool isUnlocked;
  final DateTime? createdAt;
  final String? standardName;

  MixSummary({
    required this.id,
    required this.title,
    required this.complianceColor,
    required this.qualityMatch,
    required this.totalCost,
    required this.costPerKg,
    required this.isUnlocked,
    this.createdAt,
    this.standardName,
  });

  factory MixSummary.fromJson(Map<String, dynamic> json) {
    final standard = json['standardUsed'];
    final standardName = standard is Map
        ? (standard['name']?.toString() ?? '')
        : '';
    final title = (json['batchName']?.toString().trim().isNotEmpty ?? false)
        ? json['batchName'].toString()
        : (standardName.isNotEmpty ? standardName : 'Feed Mix');

    return MixSummary(
      id: json['_id']?.toString() ?? '',
      title: title,
      complianceColor: json['complianceColor']?.toString() ?? 'Red',
      qualityMatch:
          (json['qualityMatchPercentage'] ?? json['qualityMatch'] ?? 0)
              .toDouble(),
      totalCost: (json['totalCost'] ?? 0).toDouble(),
      costPerKg: (json['costPerKg'] ?? 0).toDouble(),
      isUnlocked: json['isUnlocked'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      standardName: standardName.isEmpty ? null : standardName,
    );
  }
}

class PondSummary {
  final String id;
  final String name;
  final String species;
  final String status; // 'Healthy', 'Feeding', 'Attention'
  final int fishCount;
  final double fcr;
  final DateTime? harvestDate;

  PondSummary({
    required this.id,
    required this.name,
    required this.species,
    required this.status,
    required this.fishCount,
    required this.fcr,
    this.harvestDate,
  });

  factory PondSummary.fromJson(Map<String, dynamic> json) {
    return PondSummary(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unnamed',
      species: json['fishSpecies'] ?? 'Unknown',
      status: _determineStatus(json),
      fishCount: json['currentFishCount'] ?? 0,
      fcr: (json['fcr'] ?? 0).toDouble(),
      harvestDate: json['expectedHarvestDate'] != null
          ? DateTime.tryParse(json['expectedHarvestDate'])
          : null,
    );
  }

  static String _determineStatus(Map<String, dynamic> json) {
    final mortality = json['mortalityRate'] ?? 0;
    if (mortality > 5) return 'Attention';
    if (json['status'] == 'active') return 'Healthy';
    return json['status'] ?? 'Unknown';
  }
}

class InventorySummary {
  final int totalItems;
  final int lowStockCount;
  final int expiringSoonCount;
  final double totalValue;

  InventorySummary({
    required this.totalItems,
    required this.lowStockCount,
    required this.expiringSoonCount,
    required this.totalValue,
  });

  factory InventorySummary.empty() => InventorySummary(
    totalItems: 0,
    lowStockCount: 0,
    expiringSoonCount: 0,
    totalValue: 0,
  );

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List? ?? [];
    int lowStock = 0;
    int expiring = 0;
    double value = 0;

    for (final item in items) {
      final qty = (item['currentStockKg'] ?? 0).toDouble();
      final reorder = (item['lowStockThreshold'] ?? 0).toDouble();
      final price = (item['userLocalPrice'] ?? 0).toDouble();

      if (qty <= reorder) lowStock++;

      // Check expiry (within 30 days)
      if (item['expiryDate'] != null) {
        final expiry = DateTime.tryParse(item['expiryDate']);
        if (expiry != null && expiry.difference(DateTime.now()).inDays <= 30) {
          expiring++;
        }
      }

      value += qty * price;
    }

    return InventorySummary(
      totalItems: items.length,
      lowStockCount: lowStock,
      expiringSoonCount: expiring,
      totalValue: value,
    );
  }
}

class FinancialSummary {
  final double totalRevenue;
  final double totalExpenses;
  final double profit;
  final double profitMargin;

  FinancialSummary({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.profit,
    required this.profitMargin,
  });

  factory FinancialSummary.empty() => FinancialSummary(
    totalRevenue: 0,
    totalExpenses: 0,
    profit: 0,
    profitMargin: 0,
  );

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    final revenue = (json['totalRevenue'] ?? 0).toDouble();
    final expenses = (json['totalExpenses'] ?? 0).toDouble();
    final profit = revenue - expenses;
    final margin = revenue > 0 ? (profit / revenue) * 100 : 0;

    return FinancialSummary(
      totalRevenue: revenue,
      totalExpenses: expenses,
      profit: profit,
      profitMargin: margin.toDouble(),
    );
  }
}

@Riverpod(keepAlive: true)
class DashboardRepository extends _$DashboardRepository {
  @override
  FutureOr<DashboardData> build() async {
    return fetchDashboardData();
  }

  Future<DashboardData> fetchDashboardData() async {
    // Reactively watch user status to trigger fetch when logged in
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    if (user == null) {
      return DashboardData.empty();
    }

    try {
      final dio = await ref.watch(dioProvider.future);

      // Parallel API calls for speed
      final results = await Future.wait([
        dio.get('/batches'),
        dio.get('/inventory'),
        dio.get('/financials/pnl'),
      ]);

      // Formulations are additive for dashboard UX. Don't fail whole
      // dashboard if this endpoint has a transient issue.
      Response<dynamic>? formulationsResponse;
      try {
        formulationsResponse = await dio.get('/formulations?limit=20');
      } catch (_) {
        formulationsResponse = null;
      }

      // Parse Batches -> Ponds
      final batchesResponse = results[0].data;
      final batchesList = (batchesResponse['data'] as List?) ?? [];
      final ponds = batchesList.map((b) => PondSummary.fromJson(b)).toList();

      // Parse Inventory
      final inventoryResponse = results[1].data;
      final inventory = InventorySummary.fromJson(inventoryResponse);

      // Parse Financials
      final pnlResponse = results[2].data;
      // Try multiple potential paths for the data (defensive parsing)
      final metricsData =
          pnlResponse['data']?['metrics'] ??
          pnlResponse['metrics'] ??
          pnlResponse['data'] ??
          pnlResponse;

      final financials = FinancialSummary.fromJson(
        metricsData is Map<String, dynamic> ? metricsData : {},
      );

      final formulationsList =
          (formulationsResponse?.data is Map
                  ? (formulationsResponse!.data['formulations'] as List? ?? [])
                  : const [])
              .whereType<Map>()
              .map(
                (item) => MixSummary.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();

      return DashboardData(
        ponds: ponds,
        inventory: inventory,
        financials: financials,
        mixes: formulationsList,
      );
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  /// Refresh all dashboard data
  Future<void> refresh() async {
    debugPrint('[DashboardRepository] Refreshing dashboard data (silent)...');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchDashboardData());
  }
}
