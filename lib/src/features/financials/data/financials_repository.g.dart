// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financials_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Expenses)
const expensesProvider = ExpensesProvider._();

final class ExpensesProvider
    extends $AsyncNotifierProvider<Expenses, List<Expense>> {
  const ExpensesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expensesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expensesHash();

  @$internal
  @override
  Expenses create() => Expenses();
}

String _$expensesHash() => r'dab908f6cfffb712ac79c3be04c4464fe9c4c9fb';

abstract class _$Expenses extends $AsyncNotifier<List<Expense>> {
  FutureOr<List<Expense>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Expense>>, List<Expense>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Expense>>, List<Expense>>,
              AsyncValue<List<Expense>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Revenues)
const revenuesProvider = RevenuesProvider._();

final class RevenuesProvider
    extends $AsyncNotifierProvider<Revenues, List<Revenue>> {
  const RevenuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'revenuesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$revenuesHash();

  @$internal
  @override
  Revenues create() => Revenues();
}

String _$revenuesHash() => r'e3bc38cbda8e2defe72e2570f7c0a6b97d582568';

abstract class _$Revenues extends $AsyncNotifier<List<Revenue>> {
  FutureOr<List<Revenue>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Revenue>>, List<Revenue>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Revenue>>, List<Revenue>>,
              AsyncValue<List<Revenue>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
