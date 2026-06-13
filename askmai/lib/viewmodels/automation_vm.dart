import 'dart:developer' as developer;
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
      // 检查tab是否启用
      if (!tab.isEnabled) {
        return SubmissionResult(
          success: false,
          error: 'Tab is disabled',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

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

      // 获取网站配置或使用自定义XPath
      String inputXPath = tab.customInputXPath ?? '';
      String submitXPath = tab.customSubmitXPath ?? '';
      String? strategyName;

      // 如果没有自定义XPath，尝试从site_config获取
      if (inputXPath.isEmpty || submitXPath.isEmpty) {
        final siteConfig = _siteRegistry.getConfigByUrl(tab.url);
        if (siteConfig == null) {
          return SubmissionResult(
            success: false,
            error: 'Site configuration not found for URL: ${tab.url}',
            timestamp: DateTime.now(),
            tabId: tabId,
          );
        }
        strategyName = siteConfig.strategy;
        inputXPath = tab.customInputXPath ?? siteConfig.inputXPath;
        submitXPath = tab.customSubmitXPath ?? siteConfig.submitXPath;
      } else {
        // 如果使用了自定义配置，仍尝试获取strategy用于匹配策略
        final siteConfig = _siteRegistry.getConfigByUrl(tab.url);
        strategyName = siteConfig?.strategy;
      }

      _log('Submitting to tab: $tabId (${tab.displayName})');

      // 执行JavaScript提交
      final result = await _jsService.executeSubmit(
        controller,
        inputXPath,
        submitXPath,
        message,
        tabId,
        strategyName: strategyName,
      );

      _log('Submission result for $tabId: ${result.getStatusString()}');
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

  /// 并发提交到所有启用的标签页
  Future<List<SubmissionResult>> submitToAllTabs(
    String message,
    TabManagerVM tabManagerVM,
  ) async {
    if (tabManagerVM.tabs.isEmpty) {
      return [];
    }

    try {
      // 过滤启用的tab
      final enabledTabs = tabManagerVM.tabs.where((tab) => tab.isEnabled).toList();
      
      if (enabledTabs.isEmpty) {
        _log('No enabled tabs to submit to');
        return [];
      }

      // 创建所有提交任务
      final futures = enabledTabs.map((tab) {
        return submitToTab(tab.id, message, tab);
      }).toList();

      // 并发执行
      return await Future.wait(futures);
    } catch (e) {
      _log('Error in parallel submission', e);
      return [];
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'AutomationVM', error: error);
  }

  @override
  String toString() => 'AutomationVM()';
}
