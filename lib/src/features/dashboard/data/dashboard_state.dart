import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_state.g.dart';

/// Controls the currently selected tab index in the dashboard
@riverpod
class DashboardTabIndex extends _$DashboardTabIndex {
  @override
  int build() => 0; // Default to Home tab

  void setTab(int index) {
    state = index;
  }

  void goToInventory() => state = 2;
  void goToFinancials() => state = 3;
  void goToDiary() => state = 1;
  void goToProfile() => state = 4;
}
