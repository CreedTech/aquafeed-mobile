// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_tab.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Batches)
const batchesProvider = BatchesProvider._();

final class BatchesProvider
    extends $AsyncNotifierProvider<Batches, List<Batch>> {
  const BatchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batchesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batchesHash();

  @$internal
  @override
  Batches create() => Batches();
}

String _$batchesHash() => r'e7a296e86bcc12136731e466780c3ef5a34f2676';

abstract class _$Batches extends $AsyncNotifier<List<Batch>> {
  FutureOr<List<Batch>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Batch>>, List<Batch>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Batch>>, List<Batch>>,
              AsyncValue<List<Batch>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
