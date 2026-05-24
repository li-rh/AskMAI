import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';

/// WebView容器 - 显示单个标签页的WebView
class WebViewContainer extends StatefulWidget {
  final LLMTab? tab;
  final WebViewService webViewService;
  final TabManagerVM tabManagerVM;

  const WebViewContainer({
    Key? key,
    required this.tab,
    required this.webViewService,
    required this.tabManagerVM,
  }) : super(key: key);

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  late WebViewController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tab != null && !kIsWeb) {
      _initializeWebView();
    }
  }

  @override
  void didUpdateWidget(WebViewContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab && widget.tab != null && !kIsWeb) {
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    final tab = widget.tab!;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading page: ${error.description}'),
                duration: const Duration(seconds: 3),
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(tab.url));

    // 注册到WebViewService
    widget.webViewService.addWebView(tab.id, _controller);

    // 更新TabManagerVM中的controller
    widget.tabManagerVM.setWebViewController(tab.id, _controller);
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;

    if (tab == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.web,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No tab selected',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a tab to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    // Web平台不支持WebView，显示占位符
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info,
              size: 64,
              color: Colors.blue[400],
            ),
            const SizedBox(height: 16),
            Text(
              'WebView Demo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tab: ${tab.displayName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'URL: ${tab.url}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // 在真实的移动应用中，这里会打开WebView
              },
              child: const Text('WebView will work on mobile (Android/iOS)'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    // 不在这里清理controller，因为其他地方可能需要用它
    super.dispose();
  }
}
