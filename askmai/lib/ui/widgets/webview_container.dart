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
  Offset? _pointerDownPosition;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    if (widget.tab != null && _isMobilePlatform) {
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    final tab = widget.tab!;

    // 默认初始状态为正在加载
    widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.loading);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36')
      ..addJavaScriptChannel(
        'AskMAIDomChangeChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (!mounted) return;
          final text = message.message;
          if (text == 'active') {
            widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.active);
          } else if (text == 'idle') {
            widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.loaded);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.loading);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              // We do not immediately set WebLoadingStatus to loaded here to prevent a brief
              // flash of green before the JS framework starts rendering. Instead, the injected
              // MutationObserver will decide when it transitions to active (yellow) or loaded (green).
              _injectDomObserver();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
              widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.error);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(tab.url));

    widget.webViewService.addWebView(tab.id, _controller);
    widget.tabManagerVM.setWebViewController(tab.id, _controller);
  }

  Future<void> _injectDomObserver() async {
    if (!mounted || widget.tab == null) return;
    try {
      const js = '''
        (function() {
          if (window.AskMAIDomObserver) {
            try { window.AskMAIDomObserver.disconnect(); } catch(e) {}
          }
          if (window.AskMAICheckInterval) {
            try { clearInterval(window.AskMAICheckInterval); } catch(e) {}
          }
          
          var timer = null;
          var safetyTimer = null;
          var active = false;
          var checkInterval = null;
          
          function post(status) {
            try {
              if (window.AskMAIDomChangeChannel) {
                window.AskMAIDomChangeChannel.postMessage(status);
              } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AskMAIDomChangeChannel) {
                window.webkit.messageHandlers.AskMAIDomChangeChannel.postMessage(status);
              } else if (typeof AskMAIDomChangeChannel !== 'undefined') {
                AskMAIDomChangeChannel.postMessage(status);
              }
            } catch(e) {}
          }
          
          function isGeneratingOrThinking() {
            // 1. Check for visible stop/cancel buttons
            var stopButtons = document.querySelectorAll('button, [role="button"]');
            for (var i = 0; i < stopButtons.length; i++) {
              var btn = stopButtons[i];
              var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || btn.innerText || '').toLowerCase();
              if (label.indexOf('stop') !== -1 || label.indexOf('停止') !== -1 || label.indexOf('中断') !== -1 || label.indexOf('cancel') !== -1) {
                if (btn.offsetWidth > 0 && btn.offsetHeight > 0 && !btn.disabled) {
                  return true;
                }
              }
            }

            // 2. Check for text indicators
            var docText = document.body ? document.body.innerText : '';
            if (docText.indexOf('正在思考') !== -1 || 
                docText.indexOf('正在搜索') !== -1 || 
                docText.indexOf('正在联网') !== -1 || 
                docText.indexOf('Thinking...') !== -1 || 
                docText.indexOf('Searching...') !== -1) {
              return true;
            }

            // 3. Check for specific selectors (thinking/searching/streaming)
            var selectors = [
              '.ds-markdown--thought', 
              '.thought-block', 
              '.thinking', 
              '.searching', 
              '[data-testid="search-status"]',
              '.search-pill',
              '.result-streaming',
              '.streaming',
              '.typing-indicator',
              '.loading-indicator'
            ];
            for (var j = 0; j < selectors.length; j++) {
              var el = document.querySelector(selectors[j]);
              if (el && el.offsetWidth > 0 && el.offsetHeight > 0) {
                return true;
              }
            }

            // 4. Check for active cursor elements
            var cursors = document.querySelectorAll('.cursor, .blink, .pulse');
            for (var k = 0; k < cursors.length; k++) {
              var cursor = cursors[k];
              if (cursor.offsetWidth > 0 && cursor.offsetHeight > 0 && cursor.tagName !== 'INPUT' && cursor.tagName !== 'TEXTAREA') {
                return true;
              }
            }

            return false;
          }
          
          function updateState() {
            var generating = isGeneratingOrThinking();
            
            if (generating) {
              if (safetyTimer) {
                clearTimeout(safetyTimer);
                safetyTimer = null;
              }
              if (!active) {
                active = true;
                post("active");
              }
              if (timer) {
                clearTimeout(timer);
                timer = null;
              }
            } else {
              if (active && !timer) {
                timer = setTimeout(function() {
                  if (!isGeneratingOrThinking()) {
                    active = false;
                    post("idle");
                  }
                  timer = null;
                }, 1000);
              }
            }
          }
          
          safetyTimer = setTimeout(function() {
            if (!active) {
              post("idle");
            }
            safetyTimer = null;
          }, 3000);
          
          var observer = new MutationObserver(function(mutations) {
            if (safetyTimer) {
              clearTimeout(safetyTimer);
              safetyTimer = null;
            }
            
            if (!active) {
              active = true;
              post("active");
            }
            
            if (timer) {
              clearTimeout(timer);
              timer = null;
            }
            
            updateState();
          });
          
          observer.observe(document.body || document.documentElement, {
            childList: true,
            subtree: true,
            attributes: true,
            characterData: true
          });
          
          checkInterval = setInterval(updateState, 500);
          
          window.AskMAIDomObserver = observer;
          window.AskMAICheckInterval = checkInterval;
          return "initialized";
        })();
      ''';
      await _controller.runJavaScript(js);
    } catch (e) {
      debugPrint("Error injecting DOM observer: \$e");
    }
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

    final viewportDisabled = widget.tab?.viewportDisabled ?? false;
    final viewportTop = widget.tab?.viewportTop ?? 0;
    final viewportBottom = widget.tab?.viewportBottom ?? 0;
    final viewportLeft = widget.tab?.viewportLeft ?? 0;
    final viewportRight = widget.tab?.viewportRight ?? 0;
    final extraWidth = viewportLeft + viewportRight;
    final extraHeight = viewportTop + viewportBottom;
    final hasViewportAdjust = !viewportDisabled && (extraWidth > 0 || extraHeight > 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        Widget webViewChild = Listener(
          onPointerDown: (event) {
            _pointerDownPosition = event.position;
            _isScrolling = false;
          },
          onPointerMove: (event) {
            if (_pointerDownPosition != null) {
              final delta = event.position - _pointerDownPosition!;
              if (delta.distance > 8.0) {
                _isScrolling = true;
              }
            }
          },
          onPointerUp: (_) {
            if (!_isScrolling) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
            _pointerDownPosition = null;
            _isScrolling = false;
          },
          onPointerCancel: (_) {
            _pointerDownPosition = null;
            _isScrolling = false;
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