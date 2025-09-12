import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/auth_repository.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // nothing to initialize
  }

  Future<void> login(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = await ref.read(authServiceProvider.future);
      await authService.requestOtp(email: email);
    });
  }

  Future<void> verifyOtp(String email, String otp) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = await ref.read(authServiceProvider.future);
      await authService.verifyOtp(email: email, otp: otp);
      ref.invalidate(currentUserProvider);
    });
  }
}
