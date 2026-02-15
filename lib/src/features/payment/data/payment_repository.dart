import 'package:dio/dio.dart';
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

  PaymentService(this._dio, this._ref);

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
        _ref.invalidate(currentUserProvider);
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

/// Provides the PaymentService instance
@riverpod
Future<PaymentService> paymentService(Ref ref) async {
  final dio = await ref.watch(dioProvider.future);
  return PaymentService(dio, ref);
}
