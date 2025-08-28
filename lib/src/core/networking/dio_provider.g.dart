// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cookieJar)
const cookieJarProvider = CookieJarProvider._();

final class CookieJarProvider
    extends
        $FunctionalProvider<
          AsyncValue<PersistCookieJar>,
          PersistCookieJar,
          FutureOr<PersistCookieJar>
        >
    with $FutureModifier<PersistCookieJar>, $FutureProvider<PersistCookieJar> {
  const CookieJarProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cookieJarProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cookieJarHash();

  @$internal
  @override
  $FutureProviderElement<PersistCookieJar> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PersistCookieJar> create(Ref ref) {
    return cookieJar(ref);
  }
}

String _$cookieJarHash() => r'acd207fda687d2495112f5f0e2dd8837a660a98b';

@ProviderFor(dio)
const dioProvider = DioProvider._();

final class DioProvider
    extends $FunctionalProvider<AsyncValue<Dio>, Dio, FutureOr<Dio>>
    with $FutureModifier<Dio>, $FutureProvider<Dio> {
  const DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $FutureProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Dio> create(Ref ref) {
    return dio(ref);
  }
}

String _$dioHash() => r'e2b884805ee75adfbe94750bac8c41a9c7346c51';
