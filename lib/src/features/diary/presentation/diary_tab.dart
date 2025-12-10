import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/networking/dio_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/widgets/auth_required_view.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';

part 'diary_tab.g.dart';

/// Diary Tab - Daily activity logging (Feeding, Pond Health, etc.)
class DiaryTab extends ConsumerStatefulWidget {
  const DiaryTab({super.key});

  @override
  ConsumerState<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends ConsumerState<DiaryTab> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final batchesAsync = ref.watch(batchesProvider);
    final dateFormat = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.white,
      appBar: AppBar(
        title: const Text('Feed Diary'),
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.white,
        surfaceTintColor: Colors.transparent,
        actions: user != null
            ? [
                IconButton(
                  icon: const Icon(Iconsax.add_circle, color: AppTheme.primary),
                  onPressed: () => _showCreateBatchSheet(context, ref),
                  tooltip: 'Create Batch',
                ),
              ]
            : null,
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (_, __) => const AuthRequiredView(
          featureName: 'Daily Farm Diary',
          description:
              'Log feedings, monitor pond health, and track growth patterns daily.',
          icon: Icons.auto_stories_outlined,
        ),
        data: (user) => user == null
            ? const AuthRequiredView(
                featureName: 'Daily Farm Diary',
                description:
                    'Log feedings, monitor pond health, and track growth patterns daily.',
                icon: Icons.auto_stories_outlined,
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(batchesProvider.future),
                color: AppTheme.primary,
                child: batchesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                  error: (err, _) => _ErrorState(
                    error: ErrorHelper.getUserMessage(err),
                    onRetry: () => ref.invalidate(batchesProvider),
                  ),
                  data: (batches) => batches.isEmpty
                      ? _EmptyState(
                          onCreateBatch: () =>
                              _showCreateBatchSheet(context, ref),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          itemCount: batches.length,
                          itemBuilder: (context, index) {
                            final batch = batches[index];
                            return Column(
                              children: [
                                _BatchCard(
                                  batch: batch,
                                  dateFormat: dateFormat,
                                  onLogFeed: () =>
                                      _showLogFeedSheet(context, ref, batch),
                                ),
                                if (index < batches.length - 1)
                                  const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
                ),
              ),
      ),
    );
  }

  void _showLogFeedSheet(BuildContext context, WidgetRef ref, Batch batch) {
    final controller = TextEditingController();
    bool isLoading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Feed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          batch.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Current Stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Fed',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey600,
                            ),
                          ),
                          Text(
                            '${batch.totalFeedUsedKg.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: AppTheme.grey200),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current FCR',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey600,
                            ),
                          ),
                          Text(
                            batch.fcr.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Amount (kg)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
                decoration: InputDecoration(hintText: '0.0', suffixText: 'kg'),
                autofocus: true,
              ),
              const SizedBox(height: 12),

              // Quick amounts
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [2, 5, 10, 15, 20]
                    .map(
                      (amount) => GestureDetector(
                        onTap: () => controller.text = amount.toString(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.grey200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$amount kg',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.black,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 14),
                  ),
                ),

              CustomButton.primary(
                text: 'Log Feed',
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () async {
                        final amount = double.tryParse(controller.text);
                        if (amount == null || amount <= 0) {
                          setModalState(() => error = 'Enter a valid amount');
                          return;
                        }
                        setModalState(() {
                          isLoading = true;
                          error = null;
                        });

                        try {
                          await ref
                              .read(batchesProvider.notifier)
                              .logFeed(batch.id, amount);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Feed logged successfully'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isLoading = false;
                            error = ErrorHelper.getUserMessage(e);
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateBatchSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final fishCountController = TextEditingController();
    final pondIdController = TextEditingController(text: '1');
    bool isLoading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create New Batch',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Batch Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: 'e.g. Pond A - Jan 2025'),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fish Count',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: fishCountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: 'e.g. 5000'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pond #',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pondIdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: '1'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 14),
                  ),
                ),

              CustomButton.primary(
                text: 'Create Batch',
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final count = int.tryParse(fishCountController.text);
                        final pondId = int.tryParse(pondIdController.text) ?? 1;

                        if (name.isEmpty) {
                          setModalState(() => error = 'Enter a batch name');
                          return;
                        }
                        if (count == null || count <= 0) {
                          setModalState(
                            () => error = 'Enter a valid fish count',
                          );
                          return;
                        }

                        setModalState(() {
                          isLoading = true;
                          error = null;
                        });

                        try {
                          await ref
                              .read(batchesProvider.notifier)
                              .createBatch(name, count, pondId);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Batch created successfully'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isLoading = false;
                            error = ErrorHelper.getUserMessage(e);
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === WIDGETS ===

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final DateFormat dateFormat;
  final VoidCallback onLogFeed;

  const _BatchCard({
    required this.batch,
    required this.dateFormat,
    required this.onLogFeed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = batch.status.toLowerCase() == 'active';
    final statusColor = isActive ? AppTheme.primary : AppTheme.grey400;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkGrey : AppTheme.grey200,
          width: 1,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header with Gradient Banner or similar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: statusColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive ? Iconsax.status_up : Iconsax.timer_1,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    batch.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'STARTED: ${dateFormat.format(batch.startDate).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Iconsax.activity,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          batch.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatItem(
                        label: 'FISH COUNT',
                        value: NumberFormat.compact().format(batch.fishCount),
                        icon: Iconsax.user_tag,
                      ),
                      _StatItem(
                        label: 'TOTAL FEED',
                        value: '${batch.totalFeedUsedKg.toStringAsFixed(1)} kg',
                        icon: Iconsax.box,
                      ),
                      _StatItem(
                        label: 'CURRENT FCR',
                        value: batch.fcr.toStringAsFixed(2),
                        icon: Iconsax.chart_2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isActive)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppTheme.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: onLogFeed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.edit_2, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Log Today\'s Feed',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppTheme.grey600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.black,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateBatch;

  const _EmptyState({required this.onCreateBatch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined, size: 64, color: AppTheme.grey400),
            const SizedBox(height: 24),
            Text(
              'No Batches Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first batch to start tracking feed',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 32),
            CustomButton.primary(
              text: 'Create Batch',
              onPressed: onCreateBatch,
              leftIcon: const Icon(Icons.add),
              width: 180,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Error Loading Batches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 24),
            CustomButton.outlined(
              text: 'Try Again',
              onPressed: onRetry,
              width: 140,
            ),
          ],
        ),
      ),
    );
  }
}

// === DATA MODEL ===
class Batch {
  final String id;
  final String name;
  final int fishCount;
  final double totalFeedUsedKg;
  final double fcr;
  final String status;
  final DateTime startDate;

  Batch({
    required this.id,
    required this.name,
    required this.fishCount,
    required this.totalFeedUsedKg,
    required this.fcr,
    required this.status,
    required this.startDate,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['_id'] ?? '',
      name: json['name'] ?? json['batchName'] ?? 'Unnamed',
      fishCount: json['currentFishCount'] ?? 0,
      totalFeedUsedKg: (json['totalFeedUsedKg'] ?? 0).toDouble(),
      fcr: (json['fcr'] ?? 0).toDouble(),
      status: json['status'] ?? 'Unknown',
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
    );
  }
}

// === RIVERPOD PROVIDER ===
@riverpod
class Batches extends _$Batches {
  @override
  Future<List<Batch>> build() async {
    try {
      final dio = await ref.watch(dioProvider.future);
      final response = await dio.get('/batches?status=Active');
      final data = response.data['data'] as List? ?? [];
      return data
          .map((e) => Batch.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  Future<void> logFeed(String batchId, double amount) async {
    try {
      final dio = await ref.watch(dioProvider.future);
      await dio.post('/batches/$batchId/feed', data: {'feedAmountKg': amount});
      ref.invalidateSelf();
      ref.invalidate(dashboardRepositoryProvider);
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  Future<void> createBatch(String name, int fishCount, int pondId) async {
    try {
      final dio = await ref.watch(dioProvider.future);
      await dio.post(
        '/batches',
        data: {
          'name': name,
          'initialFishCount': fishCount,
          'pondId': pondId, // Now sending as number
        },
      );
      ref.invalidateSelf();
      ref.invalidate(dashboardRepositoryProvider);
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }
}
