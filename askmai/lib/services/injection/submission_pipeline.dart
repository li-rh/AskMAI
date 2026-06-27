import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../utils/json_utils.dart';
import 'injection_helpers.dart';
import 'text_filler.dart';

/// 统一的注入流程编排 — 所有策略共享此 4 阶段流程
///
/// Phase 0: 元素预检测（waitForElement）
/// Phase 1: 聚焦输入框
/// Phase 2: 填充内容（由 TextFiller 提供 JS）
/// Phase 3: 点击发送按钮（submitWithRetry）
class SubmissionPipeline {
  Future<SubmissionResult> execute({
    required WebViewController controller,
    required String inputXPath,
    required String submitXPath,
    required String message,
    required TextFiller filler,
    required String tabId,
    String? displayName,
    String? fallbackSubmitXPath,
    String? clickFallbackSelector,
    String? answerContentXPath,
  }) async {
    final name = displayName ?? tabId;
    final totalStart = DateTime.now();
    _log('[Pipeline:$name] ====== ${filler.name.toUpperCase()} START ====== msg.length=${message.length}');

    try {
      // Phase 0: 元素预检测（含重试）
      _log('[Pipeline:$name] Phase0-Detect: checking input element...');
      final inputDetect = await waitForElementShared(
        controller: controller,
        xpath: inputXPath,
        name: name,
        label: 'input element',
        log: _log,
      );
      if (inputDetect == null) {
        _log('[Pipeline:$name] Phase0-Detect ABORT: input element NOT found after retries');
        return SubmissionResult(
          success: false,
          error: 'Input element not found',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      if (filler.name != 'dom_input' && inputDetect['editable'] != true) {
        _log('[Pipeline:$name] Phase0-Detect WARNING: input element is NOT contenteditable!');
      }
      _log('[Pipeline:$name] Phase0-Detect: input found, tag=${inputDetect['tag']}, editable=${inputDetect['editable']}');

      // Phase 0.5: Filler 特有的预检测（如 ReactFiber 的 __reactFiber 检测）
      final preFillDetectJs = filler.buildPreFillDetectJs(inputXPath);
      if (preFillDetectJs != null) {
        _log('[Pipeline:$name] Phase0.5-PreFillDetect: running filler-specific detection...');
        final detectResult = await controller.runJavaScriptReturningResult(
          '$helpersJS\n$preFillDetectJs',
        );
        final detectOk = safeParseJsonResult(detectResult);
        _log('[Pipeline:$name] Phase0.5-PreFillDetect result: $detectOk');

        final diagJs = filler.buildPreFillDetectDiagJs(inputXPath);
        if (diagJs != null) {
          final diagResult = await controller.runJavaScriptReturningResult(
            '$helpersJS\n$diagJs',
          );
          _log('[Pipeline:$name] Phase0.5-Diag: $diagResult');
        }
      }

      // Phase 1: 聚焦输入框（可能需要多次聚焦，如 ReactSlateFiller 需要 2 次）
      final focusJs = filler.buildFocusJs(inputXPath);
      for (int i = 0; i < filler.focusAttempts; i++) {
        _log('[Pipeline:$name] Phase1-Focus${i + 1}: focusing input element (attempt $i)...');
        final focusStart = DateTime.now();
        final focusResult = await controller.runJavaScriptReturningResult(
          '$helpersJS\n$focusJs',
        );
        final focusOk = safeParseJsonResult(focusResult);
        final focusMs = DateTime.now().difference(focusStart).inMilliseconds;
        _log('[Pipeline:$name] Phase1-Focus${i + 1} result (${focusMs}ms): $focusOk');

        if (focusOk == null || focusOk['success'] != true) {
          _log('[Pipeline:$name] Phase1-Focus${i + 1}: element not found, continuing anyway...');
        }

        if (i < filler.focusAttempts - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Phase 2: 填充内容
      _log('[Pipeline:$name] Phase2-Fill: filling input with ${message.length} chars...');
      final fillStart = DateTime.now();
      final fillJs = filler.buildFillJs(inputXPath, message);
      final fillResult = await controller.runJavaScriptReturningResult(
        '$helpersJS\n$fillJs',
      );
      final fillOk = safeParseJsonResult(fillResult);
      final fillMs = DateTime.now().difference(fillStart).inMilliseconds;
      _log('[Pipeline:$name] Phase2-Fill result (${fillMs}ms): $fillOk');

      if (fillOk == null || fillOk['success'] != true) {
        final error = (fillOk?['error'] as String?) ?? 'Fill input failed';
        _log('[Pipeline:$name] Phase2-Fill FAILED: $error');
        return SubmissionResult(
          success: false,
          error: error,
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      await Future.delayed(filler.fillDelay);

      // Phase 3: 点击发送按钮（含重试验证）
      final clickResult = await submitWithRetryShared(
        controller: controller,
        inputXPath: inputXPath,
        submitXPath: submitXPath,
        clickJs: _buildClickJs(submitXPath),
        tabId: tabId,
        displayName: displayName,
        fallbackSubmitXPath: fallbackSubmitXPath,
        clickFallbackSelector: clickFallbackSelector,
        log: _log,
      );

      if (clickResult.success) {
        _log('[Pipeline:$name] Submission succeeded. Injecting answer status observer...');
        await injectAnswerStatusObserverShared(
          controller: controller,
          answerContentXPath: answerContentXPath,
          name: name,
          log: _log,
        );
      }

      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[Pipeline:$name] ====== ${filler.name.toUpperCase()} END (${totalMs}ms) ======');

      return clickResult;
    } catch (e, stack) {
      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[Pipeline:$name] EXCEPTION (${totalMs}ms): $e');
      _log('[Pipeline:$name] Stack: $stack');
      return SubmissionResult(
        success: false,
        error: 'SubmissionPipeline error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }

  String _buildClickJs(String submitXPath) => '''
    $helpersJS
    (function() {
      try {
        var btn = _findElement('${escapeJavaScript(submitXPath)}');
        if (!btn) {
          return JSON.stringify({ success: false, error: 'Submit button not found', step: 'click' });
        }
        if (_isDisabled(btn)) {
          return JSON.stringify({ success: false, error: 'Submit button is disabled', step: 'click' });
        }
        _simulateSubmit(btn);
        return JSON.stringify({ success: true, method: 'click', step: 'click' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'click' });
      }
    })()
  ''';

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'SubmissionPipeline', error: error);
  }
}
