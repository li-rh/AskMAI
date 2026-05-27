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
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(tab.url));

    widget.webViewService.addWebView(tab.id, _controller);
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

    if (!_isMobilePlatform) {
      return DesktopWebViewPlaceholder(
        url: tab.url,
        displayName: tab.displayName,
        isLoading: _isLoading,
      );
    }

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
                      final updatedTab = tab.copyWith(isDisplayed: false, isEnabled: false);
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

    final viewportTop = widget.tab?.viewportTop ?? 0;
    final viewportBottom = widget.tab?.viewportBottom ?? 0;
    final viewportLeft = widget.tab?.viewportLeft ?? 0;
    final viewportRight = widget.tab?.viewportRight ?? 0;
    final extraWidth = viewportLeft + viewportRight;
    final extraHeight = viewportTop + viewportBottom;
    final hasViewportAdjust = extraWidth > 0 || extraHeight > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        Widget webViewChild = Listener(
          onPointerDown: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: WebViewWidget(controller: _controller),
        );

        if (hasViewportAdjust) {
          final expandedWidth = availableWidth + extraWidth;
          final expandedHeight = availableHeight + extraHeight;

          webViewChild = ClipRect(
            child: SizedBox(
              width: availableWidth,
              height: availableHeight,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: expandedWidth,
                maxWidth: expandedWidth,
                minHeight: expandedHeight,
                maxHeight: expandedHeight,
                child: Transform.translate(
                  offset: Offset(
                    -viewportLeft.toDouble(),
                    -viewportTop.toDouble(),
                  ),
                  child: webViewChild,
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            webViewChild,
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
      },
    );
  }
}