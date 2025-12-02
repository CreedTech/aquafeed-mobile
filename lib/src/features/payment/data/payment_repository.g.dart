// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the PaymentService instance

@ProviderFor(paymentService)
const paymentServiceProvider = PaymentServiceProvider._();

/// Provides the PaymentService instance

final class PaymentServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaymentService>,
          PaymentService,
          FutureOr<PaymentService>
        >
    with $FutureModifier<PaymentService>, $FutureProvider<PaymentService> {
  /// Provides the PaymentService instance
  const PaymentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentServiceHash();

  @$internal
  @override
  $FutureProviderElement<PaymentService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaymentService> create(Ref ref) {
    return paymentService(ref);
  }
}

String _$paymentServiceHash() => r'b677d8d23107e417c31064ad895ac1ab8bf78da9';
