import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
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
  _CallbackVisualState _state = _CallbackVisualState.processing;
  String _message = 'Finalizing payment...';
  bool _redirectScheduled = false;
  Duration _redirectDelay = Duration.zero;
  late final ConfettiController _confettiController;
  bool _confettiPlayed = false;

  String get _status => (widget.status ?? '').trim().toLowerCase();
  String get _reference => (widget.reference ?? '').trim();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await closeInAppWebView();
      } catch (_) {
        // Ignore if there is no in-app web view to close.
      }
      await _processCallback();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  bool get _isTerminalFailureStatus =>
      _status == 'failed' ||
      _status == 'abandoned' ||
      _status == 'cancelled' ||
      _status == 'error';

  bool _isRetryableVerificationMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('not successful') ||
        normalized.contains('verification failed') ||
        normalized.contains('unable to verify') ||
        normalized.contains('timeout') ||
        normalized.contains('pending') ||
        normalized.contains('processing');
  }

  bool _isTerminalVerificationMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('does not belong') ||
        normalized.contains('missing payment reference') ||
        normalized.contains('unsupported payment currency') ||
        normalized.contains('invalid payment amount') ||
        normalized.contains('unable to determine payment owner');
  }

  void _scheduleWalletRedirect([Duration delay = const Duration(seconds: 3)]) {
    if (_redirectScheduled) return;
    if (mounted) {
      setState(() {
        _redirectScheduled = true;
        _redirectDelay = delay;
      });
    } else {
      _redirectScheduled = true;
      _redirectDelay = delay;
    }

    Future<void>.delayed(delay, () {
      if (!mounted) return;
      context.go('/wallet');
    });
  }

  void _setState(_CallbackVisualState state, String message) {
    if (!mounted) return;
    final shouldTriggerConfetti =
        state == _CallbackVisualState.success && !_confettiPlayed;

    setState(() {
      _state = state;
      _message = message;
    });

    if (shouldTriggerConfetti) {
      _confettiPlayed = true;
      _confettiController.play();
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Future<void> _processCallback() async {
    if (_reference.isEmpty) {
      _setState(
        _CallbackVisualState.failed,
        'Payment reference is missing. Please retry from Wallet.',
      );
      _scheduleWalletRedirect(const Duration(seconds: 4));
      return;
    }

    if (_isTerminalFailureStatus) {
      try {
        final paymentService = await ref.read(paymentServiceProvider.future);
        await paymentService.clearPendingReference(_reference);
      } catch (_) {
        // Ignore storage cleanup errors
      }
      _setState(
        _CallbackVisualState.failed,
        'Payment was not completed (${_capitalize(_status)}).',
      );
      _scheduleWalletRedirect(const Duration(seconds: 4));
      return;
    }

    if (_status == 'success') {
      _setState(
        _CallbackVisualState.processing,
        'Payment callback received. Confirming on server...',
      );
    }

    await _verifyAndRoute();
  }

  Future<void> _verifyAndRoute() async {
    try {
      final paymentService = await ref.read(paymentServiceProvider.future);
      const retryDelays = <Duration>[
        Duration(milliseconds: 0),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 2000),
        Duration(milliseconds: 3000),
        Duration(milliseconds: 4500),
        Duration(milliseconds: 6000),
      ];

      for (var attempt = 0; attempt < retryDelays.length; attempt++) {
        if (!mounted) return;

        if (retryDelays[attempt] > Duration.zero) {
          _setState(
            _CallbackVisualState.processing,
            'Confirming payment with server (${attempt + 1}/${retryDelays.length})...',
          );
          await Future<void>.delayed(retryDelays[attempt]);
        } else {
          _setState(_CallbackVisualState.processing, 'Verifying payment...');
        }

        final result = await paymentService.verifyPayment(_reference);
        if (!mounted) return;

        if (result.success) {
          ref.invalidate(currentUserProvider);
          _setState(_CallbackVisualState.success, result.message);
          _scheduleWalletRedirect(const Duration(seconds: 3));
          return;
        }

        if (_isTerminalVerificationMessage(result.message)) {
          _setState(_CallbackVisualState.failed, result.message);
          _scheduleWalletRedirect(const Duration(seconds: 4));
          return;
        }

        if (!_isRetryableVerificationMessage(result.message)) {
          _setState(_CallbackVisualState.failed, result.message);
          _scheduleWalletRedirect(const Duration(seconds: 4));
          return;
        }
      }

      _setState(
        _CallbackVisualState.pending,
        'Payment was received and is still being confirmed. Your wallet will update automatically.',
      );
      _scheduleWalletRedirect(const Duration(seconds: 3));
    } catch (_) {
      _setState(
        _CallbackVisualState.pending,
        'Payment confirmation is taking longer than expected. Your wallet will update automatically once confirmed.',
      );
      _scheduleWalletRedirect(const Duration(seconds: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (_state) {
      _CallbackVisualState.processing => AppTheme.primary,
      _CallbackVisualState.pending => AppTheme.info,
      _CallbackVisualState.success => AppTheme.success,
      _CallbackVisualState.failed => AppTheme.error,
    };

    final title = switch (_state) {
      _CallbackVisualState.processing => 'Processing Payment',
      _CallbackVisualState.pending => 'Confirmation Pending',
      _CallbackVisualState.success => 'Payment Successful',
      _CallbackVisualState.failed => 'Payment Not Completed',
    };

    final icon = switch (_state) {
      _CallbackVisualState.processing => Icons.autorenew_rounded,
      _CallbackVisualState.pending => Icons.hourglass_top_rounded,
      _CallbackVisualState.success => Icons.check_rounded,
      _CallbackVisualState.failed => Icons.close_rounded,
    };

    final supportText = switch (_state) {
      _CallbackVisualState.processing =>
        'Please wait while we finalize your payment.',
      _CallbackVisualState.pending =>
        'Redirecting in ${_redirectDelay.inSeconds}s. You can continue immediately if preferred.',
      _CallbackVisualState.success =>
        'Redirecting in ${_redirectDelay.inSeconds}s. You can continue immediately.',
      _CallbackVisualState.failed =>
        'Redirecting in ${_redirectDelay.inSeconds}s. You can continue immediately.',
    };

    final showContinueButton = _state != _CallbackVisualState.processing;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.16),
              Colors.white,
              color.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    emissionFrequency: 0.07,
                    numberOfParticles: 30,
                    minBlastForce: 9,
                    maxBlastForce: 20,
                    gravity: 0.2,
                    shouldLoop: false,
                    colors: const [
                      Color(0xFF14B8A6),
                      Color(0xFF22C55E),
                      Color(0xFF3B82F6),
                      Color(0xFFF59E0B),
                      Color(0xFFEF4444),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -80,
                right: -40,
                child: _GlowCircle(
                  color: color.withValues(alpha: 0.18),
                  size: 220,
                ),
              ),
              Positioned(
                bottom: -90,
                left: -50,
                child: _GlowCircle(
                  color: color.withValues(alpha: 0.12),
                  size: 250,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: color.withValues(alpha: 0.24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.black.withValues(alpha: 0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 122,
                            height: 122,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.13),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: _state == _CallbackVisualState.processing
                                  ? SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: CircularProgressIndicator(
                                        color: color,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Icon(icon, color: color, size: 56),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.grey600,
                              height: 1.5,
                            ),
                          ),
                          if (_reference.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppTheme.grey200),
                              ),
                              child: Text(
                                'Ref: $_reference',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.grey600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (_state == _CallbackVisualState.processing) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.18),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            supportText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (showContinueButton) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => context.go('/wallet'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Continue to Wallet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CallbackVisualState { processing, pending, success, failed }

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
