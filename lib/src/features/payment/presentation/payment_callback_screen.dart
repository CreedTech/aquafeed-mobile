import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../data/payment_repository.dart';

class PaymentCallbackScreen extends ConsumerStatefulWidget {
  final String? reference;
  final String? status;

  const PaymentCallbackScreen({super.key, this.reference, this.status});

  @override
  ConsumerState<PaymentCallbackScreen> createState() =>
      _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends ConsumerState<PaymentCallbackScreen> {
  bool _isProcessing = true;
  bool _isSuccess = false;
  String _message = 'Finalizing payment...';

  String get _status => (widget.status ?? '').trim().toLowerCase();
  String get _reference => (widget.reference ?? '').trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await closeInAppWebView();
      } catch (_) {
        // Ignore if there is no in-app web view to close.
      }
      await _processCallback();
    });
  }

  bool get _isTerminalFailureStatus =>
      _status == 'failed' || _status == 'abandoned' || _status == 'cancelled';

  void _scheduleWalletRedirect() {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      context.go('/wallet');
    });
  }

  Future<void> _processCallback() async {
    if (_reference.isEmpty) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _message = 'Payment reference is missing. Please retry from Wallet.';
      });
      _scheduleWalletRedirect();
      return;
    }

    if (_isTerminalFailureStatus) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _message =
            'Payment was not completed (${_status[0].toUpperCase()}${_status.substring(1)}).';
      });
      _scheduleWalletRedirect();
      return;
    }

    await _verifyAndRoute();
  }

  Future<void> _verifyAndRoute() async {
    setState(() {
      _isProcessing = true;
      _message = 'Verifying payment...';
    });

    try {
      final paymentService = await ref.read(paymentServiceProvider.future);
      final result = await paymentService.verifyPayment(_reference);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isSuccess = result.success;
        _message = result.message;
      });

      _scheduleWalletRedirect();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _message =
            'Unable to verify payment right now. Please retry from Wallet.';
      });
      _scheduleWalletRedirect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _isProcessing
        ? null
        : Icon(
            _isSuccess ? Icons.check_circle : Icons.error_outline,
            size: 64,
            color: _isSuccess ? AppTheme.success : AppTheme.error,
          );

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing)
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 3,
                        ),
                      )
                    else
                      icon!,
                    const SizedBox(height: 16),
                    Text(
                      _isProcessing
                          ? 'Processing Payment'
                          : (_isSuccess
                                ? 'Payment Successful'
                                : 'Payment Not Verified'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey600,
                        height: 1.45,
                      ),
                    ),
                    if (_reference.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Ref: $_reference',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (!_isProcessing) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Returning to Wallet...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
