import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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

  bool _hasLoadedRequest = false;
  Timer? _loadTimer;
  Timer? _pageTimeoutTimer;
  bool _showWebView = true;

  @override
  void initState() {
    super.initState();
    if (widget.tab != null && _isMobilePlatform) {
      _initializeWebView();
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _pageTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(WebViewContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab?.id != widget.tab?.id || oldWidget.tab?.url != widget.tab?.url) {
      _loadTimer?.cancel();
      _loadTimer = null;
      _pageTimeoutTimer?.cancel();
      _pageTimeoutTimer = null;
      setState(() {
        _hasLoadedRequest = false;
        _isLoading = false;
        _hasError = false;
        _showWebView = true;
      });
      if (widget.tab != null && _isMobilePlatform) {
        _initializeWebView();
      }
    } else {
      // 如果 isDisplayed 从 false 变为 true，且还未加载过，则触发加载
      final wasDisplayed = oldWidget.tab?.isDisplayed ?? false;
      final isDisplayed = widget.tab?.isDisplayed ?? false;
      if (!wasDisplayed && isDisplayed && !_hasLoadedRequest) {
        _startLoadRequest();
      } else {
        // 检查是否在延迟或懒加载策略中，由于切换激活需要立刻加载
        final activeTabId = widget.tabManagerVM.activeTabId;
        if (widget.tab != null && widget.tab!.id == activeTabId && !_hasLoadedRequest) {
          _loadRequestNow();
        }
      }
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
          if (_hasError) return; // Ignore DOM messages when displaying an error page
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
            if (url == 'about:blank') return;
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.loading);
              _startPageTimeoutTimer();
            }
          },
          onPageFinished: (String url) async {
            if (url == 'about:blank') return;
            _cancelPageTimeoutTimer();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _showWebView = true;
              });
              if (_hasError) {
                // If it already failed with an error, do not inject the DOM observer
                return;
              }
              try {
                final canGo = await _controller.canGoBack();
                debugPrint('[WebView] Page finished: $url, canGoBack: $canGo');
              } catch (e) {
                debugPrint('[WebView] Error checking canGoBack on page finish: $e');
              }
              // Set the status to loaded as baseline since resource load is complete
              widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.loaded);
              _injectDomObserver();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true && mounted) {
              _cancelPageTimeoutTimer();
              setState(() {
                _hasError = true;
                _isLoading = false;
                _showWebView = true;
              });
              widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.error);
            }
          },
          onUrlChange: (UrlChange change) async {
            try {
              final canGo = await _controller.canGoBack();
              debugPrint('[WebView] URL changed: ${change.url}, canGoBack: $canGo');
            } catch (e) {
              debugPrint('[WebView] Error checking canGoBack on URL change: $e');
            }
          },
        ),
      );

    // Setup file selector callback for Android
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnShowFileSelector((FileSelectorParams params) async {
        final List<String> paths = [];
        try {
          final bool allowMultiple = params.mode == FileSelectorMode.openMultiple;
          
          // First, split any comma-separated accept types and clean them
          final List<String> resolvedTypes = [];
          for (final type in params.acceptTypes) {
            if (type.contains(',')) {
              resolvedTypes.addAll(type.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
            } else {
              final trimmed = type.trim();
              if (trimmed.isNotEmpty) {
                resolvedTypes.add(trimmed);
              }
            }
          }
          
          debugPrint('[WebView] onShowFileSelector: resolvedTypes=$resolvedTypes, isCaptureEnabled=${params.isCaptureEnabled}');

          // 1. If capture is requested (e.g. capture="camera"), open camera directly
          if (params.isCaptureEnabled) {
            final ImagePicker picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.camera);
            if (image != null) {
              paths.add(Uri.file(image.path).toString());
            }
            return paths;
          }

          // Determine the file type filter and check if it is image-only
          FileType fileType = FileType.any;
          List<String>? allowedExtensions;
          bool isImageOnly = false;
          
          if (resolvedTypes.isNotEmpty) {
            const imageExtensions = {
              '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif',
              'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'
            };
            const videoExtensions = {
              '.mp4', '.mov', '.avi', '.mkv', '.flv', '.3gp', '.webm',
              'mp4', 'mov', 'avi', 'mkv', 'flv', '3gp', 'webm'
            };
            const audioExtensions = {
              '.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac',
              'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'
            };

            final allImages = resolvedTypes.every((t) {
              final lower = t.toLowerCase();
              return lower.startsWith('image/') || imageExtensions.contains(lower);
            });
            
            final allVideos = resolvedTypes.every((t) {
              final lower = t.toLowerCase();
              return lower.startsWith('video/') || videoExtensions.contains(lower);
            });
            
            final allAudio = resolvedTypes.every((t) {
              final lower = t.toLowerCase();
              return lower.startsWith('audio/') || audioExtensions.contains(lower);
            });
            
            if (allImages) {
              fileType = FileType.image;
              isImageOnly = true;
            } else if (allVideos) {
              fileType = FileType.video;
            } else if (allAudio) {
              fileType = FileType.audio;
            } else {
              // Extract extensions if any
              final List<String> extensions = [];
              bool hasUnmappableType = false;
              
              final Map<String, String> mimeToExt = {
                'application/pdf': 'pdf',
                'application/msword': 'doc',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
                'application/vnd.ms-excel': 'xls',
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
                'application/vnd.ms-powerpoint': 'ppt',
                'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
                'text/plain': 'txt',
                'text/html': 'html',
                'application/json': 'json',
                'application/zip': 'zip',
              };

              for (final type in resolvedTypes) {
                final lower = type.toLowerCase();
                if (lower.startsWith('.')) {
                  extensions.add(lower.substring(1));
                } else if (mimeToExt.containsKey(lower)) {
                  extensions.add(mimeToExt[lower]!);
                } else {
                  hasUnmappableType = true;
                }
              }

              if (extensions.isNotEmpty && !hasUnmappableType) {
                fileType = FileType.custom;
                allowedExtensions = extensions;
              } else {
                fileType = FileType.any;
              }
            }
          }

          // Show a beautiful modal bottom sheet to let the user select how they want to upload
          final String? selectedSource = await showModalBottomSheet<String>(
            context: context,
            builder: (BuildContext context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('从相册选择'),
                      onTap: () => Navigator.pop(context, 'gallery'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('拍照'),
                      onTap: () => Navigator.pop(context, 'camera'),
                    ),
                    if (!isImageOnly)
                      ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: const Text('选择文件/文档'),
                        onTap: () => Navigator.pop(context, 'file'),
                      ),
                  ],
                ),
              );
            },
          );

          if (selectedSource == 'gallery') {
            final ImagePicker picker = ImagePicker();
            if (allowMultiple) {
              final List<XFile> images = await picker.pickMultiImage();
              for (final image in images) {
                paths.add(Uri.file(image.path).toString());
              }
            } else {
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                paths.add(Uri.file(image.path).toString());
              }
            }
          } else if (selectedSource == 'camera') {
            final ImagePicker picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.camera);
            if (image != null) {
              paths.add(Uri.file(image.path).toString());
            }
          } else if (selectedSource == 'file') {
            final FilePickerResult? result = await FilePicker.platform.pickFiles(
              allowMultiple: allowMultiple,
              type: fileType,
              allowedExtensions: allowedExtensions,
            );
            if (result != null && result.files.isNotEmpty) {
              for (final file in result.files) {
                if (file.path != null) {
                  paths.add(Uri.file(file.path!).toString());
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[WebView] Error picking files/images: $e');
        }
        return paths;
      });
    }

    widget.webViewService.addWebView(tab.id, _controller);
    widget.tabManagerVM.setWebViewController(tab.id, _controller);

    _startLoadRequest();
  }

  void _startLoadRequest() {
    if (!mounted || widget.tab == null) return;
    final tab = widget.tab!;

    // 如果tab未显示（isDisplayed为false），先不加载它的网络请求，避免无意义加载
    if (!tab.isDisplayed) {
      widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.loading);
      return;
    }

    final settingsVM = Provider.of<AppSettingsVM>(context, listen: false);
    final strategy = settingsVM.webLoadStrategy;
    final activeTabId = widget.tabManagerVM.activeTabId;

    if (strategy == 'concurrent') {
      _loadRequestNow();
    } else if (strategy == 'lazy') {
      if (tab.id == activeTabId) {
        _loadRequestNow();
      } else {
        // 懒加载模式下未激活的标签，暂时在UI上显示骨架屏
        // 将状态重置为 loading 触发其显示骨架屏和 loading 环
        widget.tabManagerVM.setWebStatus(tab.id, WebLoadingStatus.loading);
      }
    } else if (strategy == 'sequential') {
      if (tab.id == activeTabId) {
        _loadRequestNow();
      } else {
        final displayedTabs = widget.tabManagerVM.tabs
            .where((t) => t.isDisplayed)
            .toList();
        final index = displayedTabs.indexWhere((t) => t.id == tab.id);
        final delayMs = (index >= 0 ? index : 0) * 1500;

        _loadTimer = Timer(Duration(milliseconds: delayMs), () {
          _loadRequestNow();
        });
      }
    }
  }

  void _loadRequestNow() {
    if (_hasLoadedRequest) return;
    _loadTimer?.cancel();
    _loadTimer = null;

    if (mounted && widget.tab != null) {
      setState(() {
        _hasLoadedRequest = true;
        _isLoading = true;
      });
      widget.tabManagerVM.setWebStatus(widget.tab!.id, WebLoadingStatus.loading);
      _startPageTimeoutTimer();
      _controller.loadRequest(Uri.parse(widget.tab!.url));
    }
  }

  void _startPageTimeoutTimer() {
    _pageTimeoutTimer?.cancel();
    _pageTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _isLoading && !_hasError) {
        debugPrint('[WebView] Page load timed out after 12 seconds.');
        try {
          _controller.loadRequest(Uri.parse('about:blank'));
        } catch (e) {
          debugPrint('[WebView] Error loading about:blank on timeout: $e');
        }
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        if (widget.tab != null) {
          widget.tabManagerVM.setWebStatus(widget.tab!.id, WebLoadingStatus.error);
        }
      }
    });
  }

  void _cancelPageTimeoutTimer() {
    _pageTimeoutTimer?.cancel();
    _pageTimeoutTimer = null;
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
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '网页加载失败。请检查您的网络连接或确认是否需要开启 VPN/代理服务（部分 AI 服务在特定地区需要代理访问）。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Failed to load the page. Please check your network connection or try enabling a VPN/Proxy (some AI services require specific regional access).',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                        _showWebView = false;
                      });
                      if (widget.tab != null) {
                        widget.tabManagerVM.setWebStatus(widget.tab!.id, WebLoadingStatus.loading);
                      }
                      _startPageTimeoutTimer();
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

    if (!_hasLoadedRequest || !_showWebView) {
      return SkeletonPlaceholder(
        displayName: tab.displayName,
        url: tab.url,
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
          child: Platform.isAndroid
              ? WebViewWidget.fromPlatformCreationParams(
                  params: AndroidWebViewWidgetCreationParams(
                    controller: _controller.platform,
                    displayWithHybridComposition: true,
                  ),
                )
              : WebViewWidget(controller: _controller),
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

/// 网页加载就绪占位骨架屏
class SkeletonPlaceholder extends StatefulWidget {
  final String displayName;
  final String url;

  const SkeletonPlaceholder({
    Key? key,
    required this.displayName,
    required this.url,
  }) : super(key: key);

  @override
  State<SkeletonPlaceholder> createState() => _SkeletonPlaceholderState();
}

class _SkeletonPlaceholderState extends State<SkeletonPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: theme.scaffoldBackgroundColor,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 呼吸发光 AI 标志占位符
              AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.blur_on_rounded,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // 就绪加载文字
              Text(
                '${widget.displayName} 正在就绪',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '等待激活以加载 ${widget.url}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 32),
              // 骨架屏模拟聊天气泡块
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildSkeletonLine(width: 0.4, alignLeft: true, colorScheme: colorScheme),
                    const SizedBox(height: 12),
                    _buildSkeletonLine(width: 0.7, alignLeft: false, colorScheme: colorScheme),
                    const SizedBox(height: 12),
                    _buildSkeletonLine(width: 0.5, alignLeft: true, colorScheme: colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLine({
    required double width,
    required bool alignLeft,
    required ColorScheme colorScheme,
  }) {
    return Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: AnimatedBuilder(
        animation: _opacityAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              height: 48,
              width: MediaQuery.of(context).size.width * width,
              decoration: BoxDecoration(
                color: alignLeft
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                    : colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(alignLeft ? 4 : 16),
                  bottomRight: Radius.circular(alignLeft ? 16 : 4),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    width: MediaQuery.of(context).size.width * width * 0.6,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}