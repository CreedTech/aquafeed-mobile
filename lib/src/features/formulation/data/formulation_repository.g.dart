// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'formulation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ingredients provider

@ProviderFor(ingredients)
const ingredientsProvider = IngredientsProvider._();

/// Ingredients provider

final class IngredientsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Ingredient>>,
          List<Ingredient>,
          FutureOr<List<Ingredient>>
        >
    with $FutureModifier<List<Ingredient>>, $FutureProvider<List<Ingredient>> {
  /// Ingredients provider
  const IngredientsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ingredientsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ingredientsHash();

  @$internal
  @override
  $FutureProviderElement<List<Ingredient>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Ingredient>> create(Ref ref) {
    return ingredients(ref);
  }
}

String _$ingredientsHash() => r'f32e32920ffee892f7dce9654e194aa9de8b4229';

/// Feed standards provider

@ProviderFor(feedStandards)
const feedStandardsProvider = FeedStandardsProvider._();

/// Feed standards provider

final class FeedStandardsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FeedStandard>>,
          List<FeedStandard>,
          FutureOr<List<FeedStandard>>
        >
    with
        $FutureModifier<List<FeedStandard>>,
        $FutureProvider<List<FeedStandard>> {
  /// Feed standards provider
  const FeedStandardsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedStandardsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedStandardsHash();

  @$internal
  @override
  $FutureProviderElement<List<FeedStandard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FeedStandard>> create(Ref ref) {
    return feedStandards(ref);
  }
}

String _$feedStandardsHash() => r'1ad33376f71b69287d8d4f7977fde02fc971a9e8';

/// Feed templates provider

@ProviderFor(feedTemplates)
const feedTemplatesProvider = FeedTemplatesProvider._();

/// Feed templates provider

final class FeedTemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FeedTemplate>>,
          List<FeedTemplate>,
          FutureOr<List<FeedTemplate>>
        >
    with
        $FutureModifier<List<FeedTemplate>>,
        $FutureProvider<List<FeedTemplate>> {
  /// Feed templates provider
  const FeedTemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedTemplatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedTemplatesHash();

  @$internal
  @override
  $FutureProviderElement<List<FeedTemplate>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FeedTemplate>> create(Ref ref) {
    return feedTemplates(ref);
  }
}

String _$feedTemplatesHash() => r'c2a3b0e6fcfcde35214d1e10feb451f7911eff58';

/// Formulation notifier for managing the formulation flow

@ProviderFor(FormulationNotifier)
const formulationProvider = FormulationNotifierProvider._();

/// Formulation notifier for managing the formulation flow
final class FormulationNotifierProvider
    extends
        $NotifierProvider<
          FormulationNotifier,
          AsyncValue<List<FormulationResult>?>
        > {
  /// Formulation notifier for managing the formulation flow
  const FormulationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formulationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formulationNotifierHash();

  @$internal
  @override
  FormulationNotifier create() => FormulationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<FormulationResult>?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AsyncValue<List<FormulationResult>?>>(value),
    );
  }
}

String _$formulationNotifierHash() =>
    r'cb25ac26ae85d78c2af7160786cef229d7760607';

/// Formulation notifier for managing the formulation flow

abstract class _$FormulationNotifier
    extends $Notifier<AsyncValue<List<FormulationResult>?>> {
  AsyncValue<List<FormulationResult>?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<FormulationResult>?>,
              AsyncValue<List<FormulationResult>?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<FormulationResult>?>,
                AsyncValue<List<FormulationResult>?>
              >,
              AsyncValue<List<FormulationResult>?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
