// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the AuthService instance

@ProviderFor(authService)
const authServiceProvider = AuthServiceProvider._();

/// Provides the AuthService instance

final class AuthServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<AuthService>,
          AuthService,
          FutureOr<AuthService>
        >
    with $FutureModifier<AuthService>, $FutureProvider<AuthService> {
  /// Provides the AuthService instance
  const AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $FutureProviderElement<AuthService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AuthService> create(Ref ref) {
    return authService(ref);
  }
}

String _$authServiceHash() => r'5cc1b5921ea2ea46756181736e72c31577cf6326';

/// Provides the current logged-in user (nullable if not logged in)

@ProviderFor(currentUser)
const currentUserProvider = CurrentUserProvider._();

/// Provides the current logged-in user (nullable if not logged in)

final class CurrentUserProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, FutureOr<User?>>
    with $FutureModifier<User?>, $FutureProvider<User?> {
  /// Provides the current logged-in user (nullable if not logged in)
  const CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $FutureProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<User?> create(Ref ref) {
    return currentUser(ref);
  }
}

String _$currentUserHash() => r'95db7bcc97c0ec1b99e90a28bebb20c11df6e757';
