import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/networking/dio_provider.dart';
import '../../../core/utils/error_helper.dart';

part 'auth_repository.g.dart';

/// User model
class User {
  final String id;
  final String email;
  final String name;
  final String tier;
  final double walletBalance;
  final bool hasFullAccess;
  final bool freeTrialUsed;
  final int formulaCount;
  final int farmCount;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.tier,
    required this.walletBalance,
    required this.hasFullAccess,
    required this.freeTrialUsed,
    required this.formulaCount,
    required this.farmCount,
  });

  bool get canCreateFormula => hasFullAccess || !freeTrialUsed;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? 'Farmer',
      tier: json['hasFullAccess'] == true ? 'pro' : 'free',
      walletBalance: (json['walletBalance'] ?? 0).toDouble(),
      hasFullAccess: json['hasFullAccess'] ?? false,
      freeTrialUsed: json['freeTrialUsed'] ?? false,
      formulaCount: json['formulaCount'] ?? 0,
      farmCount: json['farms']?.length ?? 0,
    );
  }
}

/// Auth service using cookie-based sessions
class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  Future<void> requestOtp({required String email}) async {
    try {
      await _dio.post('/auth/request-otp', data: {'email': email});
    } on DioException catch (e) {
      throw ErrorHelper.getUserMessage(e);
    }
  }

  Future<User> verifyOtp({required String email, required String otp}) async {
    try {
      final response = await _dio.post(
        '/auth/verify-otp',
        data: {'email': email, 'otp': otp},
      );
      // Session cookie is automatically stored by CookieManager
      return User.fromJson(response.data['user']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Invalid verification code. Please try again.';
      }
      if (e.response?.statusCode == 410) {
        throw 'Code expired. Please request a new one.';
      }
      throw ErrorHelper.getUserMessage(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Ignore logout errors
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      if (response.data['user'] != null) {
        return User.fromJson(response.data['user']);
      }
      return null;
    } on DioException {
      return null;
    }
  }
}

/// Provides the AuthService instance
@riverpod
Future<AuthService> authService(Ref ref) async {
  final dio = await ref.watch(dioProvider.future);
  return AuthService(dio);
}

/// Provides the current logged-in user (nullable if not logged in)
@riverpod
Future<User?> currentUser(Ref ref) async {
  final authService = await ref.watch(authServiceProvider.future);
  return authService.getCurrentUser();
}
