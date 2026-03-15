import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalystContext {
  final String? formulationId;
  final String? feedType;
  final String? stageCode;

  const AnalystContext({this.formulationId, this.feedType, this.stageCode});

  String get identity =>
      '${formulationId ?? ''}|${feedType ?? ''}|${stageCode ?? ''}';
}

class AnalystContextNotifier extends Notifier<AnalystContext?> {
  @override
  AnalystContext? build() => null;

  void setContext(AnalystContext context) {
    state = context;
  }

  void clear() {
    state = null;
  }
}

final analystContextProvider =
    NotifierProvider<AnalystContextNotifier, AnalystContext?>(
      AnalystContextNotifier.new,
    );
