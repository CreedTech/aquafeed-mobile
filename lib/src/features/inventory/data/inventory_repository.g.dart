// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InventoryRepository)
const inventoryRepositoryProvider = InventoryRepositoryProvider._();

final class InventoryRepositoryProvider
    extends $AsyncNotifierProvider<InventoryRepository, List<InventoryItem>> {
  const InventoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inventoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inventoryRepositoryHash();

  @$internal
  @override
  InventoryRepository create() => InventoryRepository();
}

String _$inventoryRepositoryHash() =>
    r'19c972ab6b5735138b0eada319fdf42bd5b618e8';

abstract class _$InventoryRepository
    extends $AsyncNotifier<List<InventoryItem>> {
  FutureOr<List<InventoryItem>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<InventoryItem>>, List<InventoryItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<InventoryItem>>, List<InventoryItem>>,
              AsyncValue<List<InventoryItem>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
