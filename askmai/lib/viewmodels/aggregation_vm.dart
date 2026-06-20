import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/exports.dart';
import '../services/exports.dart';
import 'automation_vm.dart';
import 'input_distributor_vm.dart';
import 'tab_manager_vm.dart';

class AggregationVM extends ChangeNotifier {
  final AutomationVM _automationVM;
  final TabManagerVM _tabManagerVM;
  final InputDistributorVM _inputDistributorVM;
  final ResponseExtractor _extractor;
  final PromptComposer _composer;
  final WebViewService _webViewService;
  final SiteRegistry _siteRegistry;
  final PreferencesService _prefsService;

  bool _isAggregating = false;
  bool get isAggregating => _isAggregating;

  AggregationVM(
    this._automationVM,
    this._tabManagerVM,
    this._inputDistributorVM,
    this._extractor,
    this._composer,
    this._webViewService,
    this._siteRegistry,
    this._prefsService,
  );

  Future<AggregationResult> aggregate(String targetTabId) async {
    final target = _tabManagerVM.getTab(targetTabId);
    if (target == null) {
      return AggregationResult(success: false, message: '目标标签页不存在');
    }

    final sources = _tabManagerVM.tabs
        .where((t) => t.isEnabled && t.id != targetTabId)
        .toList();

    if (sources.isEmpty) {
      return AggregationResult(success: false, message: '没有可用的源 AI 回答');
    }

    _isAggregating = true;
    notifyListeners();

    try {
      final tasks = sources.map((tab) async {
        final controller = _webViewService.getWebView(tab.id);
        debugPrint('[AggregationVM] source=${tab.displayName} controller=${controller != null ? "ok" : "NULL"}');
        if (controller == null) return null;
        final config = _siteRegistry.getConfigByUrl(tab.url);
        debugPrint('[AggregationVM] source=${tab.displayName} url=${tab.url} config=${config != null ? "ok(${config.id})" : "NULL"}');
        if (config == null) return null;
        debugPrint('[AggregationVM] source=${tab.displayName} copyButtonXPath=${config.copyButtonXPath}');
        debugPrint('[AggregationVM] source=${tab.displayName} responseXPath=${config.responseXPath}');
        try {
          final text = await _extractor
              .extract(controller: controller, siteConfig: config)
              .timeout(const Duration(seconds: 2));
          debugPrint('[AggregationVM] source=${tab.displayName} extracted=${text != null ? "ok(len=${text.length})" : "NULL"}');
          return text != null ? TabResponse(tab.displayName, text) : null;
        } catch (e) {
          debugPrint('[AggregationVM] source=${tab.displayName} extract error: $e');
          return null;
        }
      }).toList();

      final results = await Future.wait(tasks);
      final successful = results.whereType<TabResponse>().toList();

      if (successful.isEmpty) {
        return AggregationResult(success: false, message: '未提取到任何回答');
      }

      final prompt = _composer.compose(
        originalQuestion: _inputDistributorVM.lastBroadcastMessage,
        responses: successful,
      );

      final submitResult = await _automationVM.submitToTab(
        target.id, prompt, target,
      );

      final skipped = sources.length - successful.length;

      if (submitResult.success) {
        _tabManagerVM.setWebStatus(targetTabId, WebLoadingStatus.loaded);
        _inputDistributorVM.clearTabSubmissionStatus(targetTabId);
        await _prefsService.setLastAggregateTargetId(targetTabId);
        final msg = skipped > 0
            ? '已聚合 ${successful.length} 个回答到 ${target.displayName}（$skipped 个跳过）'
            : '已聚合 ${successful.length} 个回答到 ${target.displayName}';
        return AggregationResult(success: true, message: msg);
      } else {
        return AggregationResult(
          success: false,
          message: '聚合发送失败: ${submitResult.error}',
        );
      }
    } catch (e) {
      _log('Aggregation error', e);
      return AggregationResult(success: false, message: '聚合出错: $e');
    } finally {
      _isAggregating = false;
      notifyListeners();
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'AggregationVM', error: error);
  }
}

class AggregationResult {
  final bool success;
  final String message;

  AggregationResult({required this.success, required this.message});
}
