import 'dart:async';
import 'package:flutter/material.dart';

/// Airbnb-style floating toast used across payment and unlock flows.
class AirbnbToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context: context,
      message: message,
      iconColor: const Color(0xFF008489),
      icon: Icons.check,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context: context,
      message: message,
      iconColor: const Color(0xFFE53935),
      icon: Icons.priority_high,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context: context,
      message: message,
      iconColor: const Color(0xFF222222),
      icon: Icons.info_outline,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context: context,
      message: message,
      iconColor: const Color(0xFFFFB400),
      icon: Icons.priority_high,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _show({
    required BuildContext context,
    required String message,
    required Color iconColor,
    required IconData icon,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();

    _currentEntry = OverlayEntry(
      builder: (context) => _AirbnbToastWidget(
        message: message,
        iconColor: iconColor,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AirbnbToastWidget extends StatefulWidget {
  final String message;
  final Color iconColor;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _AirbnbToastWidget({
    required this.message,
    required this.iconColor,
    required this.icon,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_AirbnbToastWidget> createState() => _AirbnbToastWidgetState();
}

class _AirbnbToastWidgetState extends State<_AirbnbToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: keyboardInset + 100,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              widget.onDismiss();
                              widget.onAction?.call();
                            },
                            child: Text(
                              widget.actionLabel!,
                              style: const TextStyle(
                                color: Color(0xFF222222),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: Color(0xFF717171),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
