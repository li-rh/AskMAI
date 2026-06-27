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
    final startTime = DateTime.now();
    _log('[Stage4-SingleTab] START tab=${tab.displayName} ($tabId), message.length=${message.length}');

    try {
      // 检查tab是否启用
      if (!tab.isEnabled) {
        _log('[Stage4-SingleTab] SKIP tab=${tab.displayName}: tab is disabled');
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
        _log('[Stage4-SingleTab] FAIL tab=${tab.displayName}: WebView controller NOT found for tabId=$tabId');
        return SubmissionResult(
          success: false,
          error: 'WebView not found for tab: $tabId',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      _log('[Stage4-SingleTab] WebView controller obtained for tab=${tab.displayName}');

      // 获取网站配置或使用自定义XPath
      String inputXPath = tab.customInputXPath ?? '';
      String submitXPath = tab.customSubmitXPath ?? '';
      String? answerContentXPath = tab.customAnswerContentXPath;
      String? strategyName;

      final siteConfig = _siteRegistry.getConfigByUrl(tab.url);

      if (inputXPath.isEmpty || submitXPath.isEmpty) {
        if (siteConfig == null) {
          _log('[Stage4-SingleTab] FAIL tab=${tab.displayName}: Site config NOT found for URL=${tab.url}');
          return SubmissionResult(
            success: false,
            error: 'Site configuration not found for URL: ${tab.url}',
            timestamp: DateTime.now(),
            tabId: tabId,
          );
        }
        strategyName = tab.customStrategy ?? siteConfig.strategy;
        inputXPath = tab.customInputXPath ?? siteConfig.inputXPath;
        submitXPath = tab.customSubmitXPath ?? siteConfig.submitXPath;
        _log('[Stage4-SingleTab] XPath from site_config: strategy=$strategyName');
      } else {
        // 如果使用了自定义配置，仍尝试获取strategy用于匹配策略
        strategyName = tab.customStrategy ?? siteConfig?.strategy;
        _log('[Stage4-SingleTab] XPath from tab custom: strategy=$strategyName');
      }

      answerContentXPath ??= siteConfig?.answerContentXPath;
      if (answerContentXPath == 'TODO_FILL_ME') {
        answerContentXPath = null;
      }

      _log('[Stage4-SingleTab] Resolved XPaths for tab=${tab.displayName}:');
      _log('[Stage4-SingleTab]   inputXPath="$inputXPath"');
      _log('[Stage4-SingleTab]   submitXPath="$submitXPath"');
      _log('[Stage4-SingleTab]   answerContentXPath="$answerContentXPath"');
      _log('[Stage4-SingleTab]   strategy="$strategyName"');

      // 执行JavaScript提交
      _log('[Stage4-SingleTab] Delegating to JavascriptService.executeSubmit...');
      final result = await _jsService.executeSubmit(
        controller,
        inputXPath,
        submitXPath,
        message,
        tabId,
        strategyName: strategyName,
        displayName: tab.displayName,
        answerContentXPath: answerContentXPath,
      );

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      _log('[Stage4-SingleTab] DONE tab=${tab.displayName} ($tabId): ${result.getStatusString()} (${elapsed}ms)');
      if (!result.success) {
        _log('[Stage4-SingleTab]   error: ${result.error}');
      }
      return result;
    } catch (e, stack) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      _log('[Stage4-SingleTab] EXCEPTION tab=${tab.displayName}: $e (${elapsed}ms)');
      _log('[Stage4-SingleTab]   stack: $stack');
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
    final startTime = DateTime.now();
    _log('[Stage3-Parallel] START, total tabs=${tabManagerVM.tabs.length}, message.length=${message.length}');

    if (tabManagerVM.tabs.isEmpty) {
      _log('[Stage3-Parallel] SKIP: tabManagerVM.tabs is empty');
      return [];
    }

    try {
      // 过滤启用的tab
      final enabledTabs = tabManagerVM.tabs.where((tab) => tab.isEnabled).toList();
      
      if (enabledTabs.isEmpty) {
        _log('[Stage3-Parallel] No enabled tabs to submit to');
        return [];
      }

      _log('[Stage3-Parallel] ${enabledTabs.length} enabled tabs, launching parallel Future.wait:');
      for (var tab in enabledTabs) {
        _log('[Stage3-Parallel]   -> ${tab.displayName} (${tab.id})');
      }

      // 创建所有提交任务
      final futures = enabledTabs.map((tab) {
        return submitToTab(tab.id, message, tab);
      }).toList();

      // 并发执行
      final results = await Future.wait(futures);
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      _log('[Stage3-Parallel] ALL DONE (${elapsed}ms), ${results.length} results');

      return results;
    } catch (e, stack) {
      _log('[Stage3-Parallel] ERROR in parallel submission: $e');
      _log('[Stage3-Parallel] Stack: $stack');
      return [];
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'AutomationVM', error: error);
  }

  @override
  String toString() => 'AutomationVM()';
}
