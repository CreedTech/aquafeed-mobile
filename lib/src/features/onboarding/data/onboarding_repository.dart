import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_repository.g.dart';

class OnboardingRepository {
  final FlutterSecureStorage _storage;
  static const _onboardingKey = 'has_completed_onboarding_v1';

  OnboardingRepository(this._storage);

  Future<bool> hasCompletedOnboarding() async {
    final value = await _storage.read(key: _onboardingKey);
    return value == 'true';
  }

  Future<void> completeOnboarding() async {
    await _storage.write(key: _onboardingKey, value: 'true');
  }
}

@riverpod
OnboardingRepository onboardingRepository(Ref ref) {
  return OnboardingRepository(const FlutterSecureStorage());
}

@riverpod
Future<bool> hasCompletedOnboarding(Ref ref) async {
  final repository = ref.watch(onboardingRepositoryProvider);
  return repository.hasCompletedOnboarding();
}
