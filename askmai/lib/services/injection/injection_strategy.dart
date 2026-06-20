import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import 'injection_helpers.dart';
import 'text_filler.dart';
import 'submission_pipeline.dart';

/// 注入策略的基类
///
/// 新策略通过 [TextFiller] + [SubmissionPipeline] 组合实现。
/// 旧策略 (GenericStrategy) 继承此类直接实现 [executeSubmit]。
abstract class InjectionStrategy {
  /// 执行表单提交操作
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId, {
    String? displayName,
  });

  void _log(String message, [Object? error]) {
    developer.log(message, name: runtimeType.toString(), error: error);
  }

  /// 等待元素出现在页面上（委托给 [waitForElement]）
  Future<Map<String, dynamic>?> waitForElement({
    required WebViewController controller,
    required String xpath,
    required String name,
    String label = 'element',
    int maxRetries = 5,
    int intervalMs = 200,
  }) =>
      waitForElementShared(
        controller: controller,
        xpath: xpath,
        name: name,
        label: label,
        maxRetries: maxRetries,
        intervalMs: intervalMs,
        log: _log,
      );

  /// 统一的发送按钮提交流程（委托给 [submitWithRetryShared]）
  Future<SubmissionResult> submitWithRetry({
    required WebViewController controller,
    required String inputXPath,
    required String submitXPath,
    required String clickJs,
    required String tabId,
    String? displayName,
    String? fallbackSubmitXPath,
    String? clickFallbackSelector,
    int maxRetries = 10,
  }) =>
      submitWithRetryShared(
        controller: controller,
        inputXPath: inputXPath,
        submitXPath: submitXPath,
        clickJs: clickJs,
        tabId: tabId,
        displayName: displayName,
        fallbackSubmitXPath: fallbackSubmitXPath,
        clickFallbackSelector: clickFallbackSelector,
        maxRetries: maxRetries,
        log: _log,
      );
}

/// 基于 TextFiller 的注入策略 — 通过 [SubmissionPipeline] 执行统一的 4 阶段流程
///
/// 这是新增策略的标准方式：只需创建一个 [TextFiller] 实现，无需复制流程代码。
class FillerInjectionStrategy extends InjectionStrategy {
  final TextFiller filler;

  FillerInjectionStrategy({required this.filler});

  @override
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId, {
    String? displayName,
  }) {
    return SubmissionPipeline().execute(
      controller: controller,
      inputXPath: inputXPath,
      submitXPath: submitXPath,
      message: message,
      filler: filler,
      tabId: tabId,
      displayName: displayName,
    );
  }
}
