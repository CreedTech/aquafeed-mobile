import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/networking/dio_provider.dart';
import '../../auth/data/auth_repository.dart';

part 'payment_repository.g.dart';

/// Payment initialization response
class PaymentInit {
  final String reference;
  final String accessCode;
  final String authorizationUrl;

  PaymentInit({
    required this.reference,
    required this.accessCode,
    required this.authorizationUrl,
  });

  factory PaymentInit.fromJson(Map<String, dynamic> json) {
    return PaymentInit(
      reference: json['reference'] ?? '',
      accessCode: json['access_code'] ?? '',
      authorizationUrl: json['authorization_url'] ?? '',
    );
  }
}

class PaymentVerificationResult {
  final bool success;
  final String message;
  final double? amount;
  final bool alreadyProcessed;

  PaymentVerificationResult({
    required this.success,
    required this.message,
    this.amount,
    this.alreadyProcessed = false,
  });
}

/// Payment service for handling payments via backend
class PaymentService {
  final Dio _dio;
  final Ref _ref;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _pendingPaymentStorageKey = 'pending_payment_refs_v1';
  static const Duration _pendingReferenceRetention = Duration(hours: 48);

  PaymentService(this._dio, this._ref);

  bool _isTerminalFailureMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('not successful') ||
        normalized.contains('cancelled') ||
        normalized.contains('abandoned') ||
        normalized.contains('failed') ||
        normalized.contains('does not belong');
  }

  Future<List<Map<String, dynamic>>> _readPendingEntries() async {
    final raw = await _secureStorage.read(key: _pendingPaymentStorageKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];

      return decoded
          .whereType<Map>()
          .map(
            (entry) => {
              'reference': entry['reference']?.toString() ?? '',
              'createdAt': (entry['createdAt'] is int)
                  ? entry['createdAt'] as int
                  : int.tryParse(entry['createdAt']?.toString() ?? '') ?? 0,
            },
          )
          .where((entry) => (entry['reference'] as String).isNotEmpty)
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writePendingEntries(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) {
      await _secureStorage.delete(key: _pendingPaymentStorageKey);
      return;
    }

    await _secureStorage.write(
      key: _pendingPaymentStorageKey,
      value: jsonEncode(entries),
    );
  }

  Future<void> rememberPendingReference(String reference) async {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return;

    final entries = await _readPendingEntries();
    entries.removeWhere((entry) => entry['reference'] == trimmed);
    entries.add({
      'reference': trimmed,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _writePendingEntries(entries);
  }

  Future<void> clearPendingReference(String reference) async {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return;

    final entries = await _readPendingEntries();
    entries.removeWhere((entry) => entry['reference'] == trimmed);
    await _writePendingEntries(entries);
  }

  Future<List<String>> getPendingReferences() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = await _readPendingEntries();

    final fresh = entries.where((entry) {
      final createdAt = (entry['createdAt'] as int?) ?? 0;
      return now - createdAt <= _pendingReferenceRetention.inMilliseconds;
    }).toList();

    if (fresh.length != entries.length) {
      await _writePendingEntries(fresh);
    }

    return fresh
        .map((entry) => entry['reference']?.toString() ?? '')
        .where((reference) => reference.isNotEmpty)
        .toList();
  }

  Future<void> recoverPendingPayments() async {
    final references = await getPendingReferences();
    for (final reference in references) {
      final result = await verifyPayment(reference);
      if (result.success || _isTerminalFailureMessage(result.message)) {
        await clearPendingReference(reference);
      }
    }
  }

  /// Initialize payment for wallet top-up
  Future<PaymentInit> initializeTopUp(int amount) async {
    final response = await _dio.post(
      '/payments/deposit',
      data: {'amount': amount},
    );
    return PaymentInit.fromJson(response.data);
  }

  /// Verify payment after completion
  Future<PaymentVerificationResult> verifyPayment(String reference) async {
    try {
      final response = await _dio.get('/payments/verify?reference=$reference');
      final data = response.data;
      final success = response.statusCode == 200;

      if (success) {
        await clearPendingReference(reference);
      }

      return PaymentVerificationResult(
        success: success,
        message: (data is Map && data['message'] != null)
            ? data['message'].toString()
            : (success
                  ? 'Payment verified successfully'
                  : 'Verification failed'),
        amount: (data is Map && data['amount'] != null)
            ? (data['amount'] as num).toDouble()
            : null,
        alreadyProcessed: data is Map && data['alreadyProcessed'] == true
            ? true
            : false,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map
          ? (data['message']?.toString() ??
                data['error']?.toString() ??
                'Verification failed')
          : 'Verification failed';
      return PaymentVerificationResult(success: false, message: message);
    }
  }

  /// Grant full access (deduct ₦10,000 from wallet)
  Future<Map<String, dynamic>> grantFullAccess() async {
    final response = await _dio.post('/payments/grant-access');
    _ref.invalidate(currentUserProvider);
    return response.data;
  }
}

/// Runs once per app lifecycle to recover unresolved payment references.
final paymentStartupRecoveryProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return;

  final paymentService = await ref.read(paymentServiceProvider.future);
  await paymentService.recoverPendingPayments();
});

/// Provides the PaymentService instance
@riverpod
Future<PaymentService> paymentService(Ref ref) async {
  final dio = await ref.watch(dioProvider.future);
  return PaymentService(dio, ref);
}
