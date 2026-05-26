import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';
import 'desktop_web_viewer.dart';

/// 检查是否是移动平台
bool get _isMobilePlatform => Platform.isAndroid || Platform.isIOS;

/// WebView容器 - 显示单个标签页的WebView
/// 支持移动端(Android/iOS)的真实WebView和桌面端的占位符
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
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.tab != null && _isMobilePlatform) {
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
              _hasError = false;
              _errorMessage = '';
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print(
              'WebView error: ${error.description} (isForMainFrame: ${error.isForMainFrame}, url: ${error.url})',
            );
            // 只对主页加载失败处理，忽略子资源 (JS/CSS/图片/埋点) 的错误
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (tab == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tab selected',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a tab to get started',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Desktop平台显示占位符，使用外部浏览器
    if (!_isMobilePlatform) {
      return DesktopWebViewPlaceholder(
        url: tab.url,
        displayName: tab.displayName,
        isLoading: _isLoading,
      );
    }

    // 加载失败时显示错误页面
    if (_hasError) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Failed to Load Page', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'URL: ${tab.url}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // 不显示此tab
                      final updatedTab = tab.copyWith(isDisplayed: false);
                      widget.tabManagerVM.updateTab(updatedTab);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close Tab'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Listener(
          onPointerDown: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: WebViewWidget(controller: _controller),
        ),
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
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
