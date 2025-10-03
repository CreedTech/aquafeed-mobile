// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controls the currently selected tab index in the dashboard

@ProviderFor(DashboardTabIndex)
const dashboardTabIndexProvider = DashboardTabIndexProvider._();

/// Controls the currently selected tab index in the dashboard
final class DashboardTabIndexProvider
    extends $NotifierProvider<DashboardTabIndex, int> {
  /// Controls the currently selected tab index in the dashboard
  const DashboardTabIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardTabIndexProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardTabIndexHash();

  @$internal
  @override
  DashboardTabIndex create() => DashboardTabIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$dashboardTabIndexHash() => r'217697f3900ec1a792f6f91b9a3159a04bc4735d';

/// Controls the currently selected tab index in the dashboard

abstract class _$DashboardTabIndex extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
