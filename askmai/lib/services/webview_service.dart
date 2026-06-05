import 'package:webview_flutter/webview_flutter.dart';

/// WebView实例管理服务 - 单例模式
class WebViewService {
  static final WebViewService _instance = WebViewService._internal();

  final Map<String, WebViewController> _webViewControllers = {};

  factory WebViewService() {
    return _instance;
  }

  WebViewService._internal();

  /// 添加WebView控制器
  void addWebView(String tabId, WebViewController controller) {
    _webViewControllers[tabId] = controller;
  }

  /// 获取指定tabId的WebView控制器
  WebViewController? getWebView(String tabId) {
    return _webViewControllers[tabId];
  }

  /// 移除WebView
  void removeWebView(String tabId) {
    _webViewControllers.remove(tabId);
  }

  /// 获取所有WebView控制器
  List<WebViewController> getAllWebViews() {
    return _webViewControllers.values.toList();
  }

  /// 获取所有tabId
  List<String> getAllTabIds() {
    return _webViewControllers.keys.toList();
  }

  /// 检查WebView是否存在
  bool hasWebView(String tabId) {
    return _webViewControllers.containsKey(tabId);
  }

  /// 清空所有WebView
  void clearAll() {
    _webViewControllers.clear();
  }

  /// 获取WebView数量
  int get webViewCount => _webViewControllers.length;

  /// 刷新指定tab的WebView
  Future<void> reloadWebView(String tabId, {String? originalUrl}) async {
    final controller = _webViewControllers[tabId];
    if (controller != null) {
      try {
        final currentUrl = await controller.currentUrl();
        if ((currentUrl == null || currentUrl == 'about:blank') && originalUrl != null) {
          await controller.loadRequest(Uri.parse(originalUrl));
        } else {
          await controller.reload();
        }
      } catch (e) {
        if (originalUrl != null) {
          await controller.loadRequest(Uri.parse(originalUrl));
        } else {
          await controller.reload();
        }
      }
    }
  }

  /// 导航指定tab的WebView到新URL
  Future<void> navigateWebView(String tabId, String url) async {
    final controller = _webViewControllers[tabId];
    if (controller != null) {
      await controller.loadRequest(Uri.parse(url));
    }
  }

  @override
  String toString() => 'WebViewService(count: $webViewCount)';
}
