import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';

class PaymentCheckoutWebViewScreen extends StatefulWidget {
  final String checkoutUrl;

  const PaymentCheckoutWebViewScreen({super.key, required this.checkoutUrl});

  @override
  State<PaymentCheckoutWebViewScreen> createState() =>
      _PaymentCheckoutWebViewScreenState();
}

class _PaymentCheckoutWebViewScreenState
    extends State<PaymentCheckoutWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  bool _isPaymentCallbackUri(Uri uri) {
    if (uri.scheme == 'aquafeed') {
      final normalizedPath = uri.path.toLowerCase().replaceAll(
        RegExp(r'/+$'),
        '',
      );
      final host = uri.host.toLowerCase();
      if ((host == 'payment' && normalizedPath == '/callback') ||
          normalizedPath == '/payment/callback' ||
          normalizedPath == '/callback') {
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null && _isPaymentCallbackUri(uri) && mounted) {
              Navigator.of(context).pop(uri);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isPaymentCallbackUri(uri)) {
              Navigator.of(context).pop(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              color: AppTheme.primary,
              backgroundColor: AppTheme.grey200,
              minHeight: 2,
            ),
        ],
      ),
    );
  }
}
