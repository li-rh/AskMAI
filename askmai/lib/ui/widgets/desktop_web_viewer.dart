import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView操作接口 - 抽象不同平台的实现
abstract class WebViewOperator {
  Future<void> loadUrl(String url);
  Future<String?> executeJavaScript(String javaScript);
  void dispose();
}

/// 移动端WebView操作实现
class MobileWebViewOperator implements WebViewOperator {
  final WebViewController _controller;

  MobileWebViewOperator(this._controller);

  @override
  Future<void> loadUrl(String url) async {
    await _controller.loadRequest(Uri.parse(url));
  }

  @override
  Future<String?> executeJavaScript(String javaScript) async {
    final result = await _controller.runJavaScriptReturningResult(javaScript);
    return result?.toString();
  }

  @override
  void dispose() {
    // WebViewController不需要手动dispose
  }
}

/// Desktop WebView占位符 - Windows/Linux使用外部浏览器
class DesktopWebViewPlaceholder extends StatelessWidget {
  final String url;
  final String displayName;
  final VoidCallback? onOpenBrowser;
  final bool isLoading;

  const DesktopWebViewPlaceholder({
    Key? key,
    required this.url,
    required this.displayName,
    this.onOpenBrowser,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const CircularProgressIndicator()
          else
            Icon(
              Icons.desktop_windows,
              size: 80,
              color: Colors.blue[400],
            ),
          const SizedBox(height: 24),
          Text(
            displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              url,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Colors.grey[700],
                  ),
            ),
          ),
          const SizedBox(height: 24),
          if (!isLoading) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in Browser'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'WebView works on mobile. Click to open in your browser.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}