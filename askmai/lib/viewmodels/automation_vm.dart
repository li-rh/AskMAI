import 'package:flutter/foundation.dart';
import '../models/exports.dart';
import '../services/exports.dart';
import 'tab_manager_vm.dart';

/// 自动化引擎ViewModel - 处理JavaScript注入和提交
class AutomationVM extends ChangeNotifier {
  final WebViewService _webViewService;
  final JavascriptService _jsService;
  final SiteRegistry _siteRegistry;

  AutomationVM(
    this._webViewService,
    this._jsService,
    this._siteRegistry,
  );

  /// 提交到单个标签页
  Future<SubmissionResult> submitToTab(
    String tabId,
    String message,
    LLMTab tab,
  ) async {
    try {
      // 获取WebViewController
      final controller = _webViewService.getWebView(tabId);
      if (controller == null) {
        return SubmissionResult(
          success: false,
          error: 'WebView not found for tab: $tabId',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      // 获取网站配置
      final siteConfig = _siteRegistry.getConfigByUrl(tab.url);
      if (siteConfig == null) {
        return SubmissionResult(
          success: false,
          error: 'Site configuration not found for URL: ${tab.url}',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      print(
        'Submitting to tab: $tabId (${tab.displayName})',
      );

      // 执行JavaScript提交
      final result = await _jsService.executeSubmit(
        controller,
        siteConfig.inputXPath,
        siteConfig.submitXPath,
        message,
        tabId,
      );

      print('Submission result for $tabId: ${result.getStatusString()}');
      return result;
    } catch (e) {
      return SubmissionResult(
        success: false,
        error: 'Submission error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }

  /// 并发提交到所有标签页
  Future<List<SubmissionResult>> submitToAllTabs(
    String message,
    TabManagerVM tabManagerVM,
  ) async {
    if (tabManagerVM.tabs.isEmpty) {
      return [];
    }

    try {
      // 创建所有提交任务
      final futures = tabManagerVM.tabs.map((tab) {
        return submitToTab(tab.id, message, tab);
      }).toList();

      // 并发执行
      return await Future.wait(futures);
    } catch (e) {
      print('Error in parallel submission: $e');
      return [];
    }
  }

  @override
  String toString() => 'AutomationVM()';
}
