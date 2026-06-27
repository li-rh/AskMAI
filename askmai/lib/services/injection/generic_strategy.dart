import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../utils/json_utils.dart';
import 'injection_helpers.dart';
import 'injection_strategy.dart';

/// @deprecated 已拆分为更专注的独立策略，此类仅供向后兼容。
/// 请迁移到：
///   - [DomInputFiller]       → strategy: "dom_input"       (textarea/input)
///   - [ExecCommandFiller]    → strategy: "exec_command"     (contenteditable)
///   - [ReactSlateFiller]     → strategy: "react_slate"      (React + Slate.js SPA)
///
/// GenericStrategy 保留原有逻辑（不再维护），用于向后兼容没有指定 strategy 的旧配置。
class GenericStrategy extends InjectionStrategy {
  static const String _focusInputJS = r'''
    function focusInput(inputSelector) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input not found', step: 'focus' });
        }
        _simulateClick(el);
        el.focus();
        if (el.isContentEditable || el.contentEditable === 'true') {
          var sel = window.getSelection();
          var rng = document.createRange();
          rng.selectNodeContents(el);
          rng.collapse(false);
          sel.removeAllRanges();
          sel.addRange(rng);
        }
        el.focus();
        return JSON.stringify({ success: true, step: 'focus' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'focus' });
      }
    }
  ''';

  static const String _fillInputJS = r'''
    function fillInput(inputSelector, messageText) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input not found', step: 'fill' });
        }
        if (el.isContentEditable || el.contentEditable === 'true') {
          el.focus();
          var sel = window.getSelection();
          var rng = document.createRange();
          rng.selectNodeContents(el);
          sel.removeAllRanges();
          sel.addRange(rng);
          var success = document.execCommand('insertText', false, messageText);
          if (!success) {
            var dataTransfer = new DataTransfer();
            dataTransfer.setData('text/plain', messageText);
            var pasteEvent = new ClipboardEvent('paste', {
              clipboardData: dataTransfer,
              bubbles: true,
              cancelable: true
            });
            el.dispatchEvent(pasteEvent);
            if (!el.textContent.includes(messageText)) {
              el.textContent = messageText;
              el.dispatchEvent(new Event('input',  { bubbles: true }));
              el.dispatchEvent(new Event('change', { bubbles: true }));
            }
          }
        } else {
          var proto = el.tagName === 'TEXTAREA'
            ? window.HTMLTextAreaElement.prototype
            : window.HTMLInputElement.prototype;
          var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
          setter.call(el, messageText);
          el.dispatchEvent(new Event('input',  { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }
        return JSON.stringify({ success: true, step: 'fill' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'fill' });
      }
    }
  ''';

  /// 注意：移除了 Enter 兜底，按钮 disabled / 未找到时直接返回失败。
  static const String _clickSubmitJS = r'''
    function clickSubmit(submitSelector) {
      try {
        var btn = _findElement(submitSelector);
        if (!btn) {
          return JSON.stringify({ success: false, error: 'Submit button not found', step: 'click' });
        }
        if (_isDisabled(btn)) {
          return JSON.stringify({ success: false, error: 'Submit button is disabled', step: 'click' });
        }
        _simulateSubmit(btn);
        return JSON.stringify({ success: true, method: 'click' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'click' });
      }
    }
  ''';

  @override
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId, {
    String? displayName,
    String? answerContentXPath,
  }) async {
    final name = displayName ?? tabId;
    final totalStart = DateTime.now();
    _log('[Generic:$name] ====== STRATEGY START ====== msg.length=${message.length}');

    try {
      // Phase 0: 元素预检测（含重试）
      _log('[Generic:$name] Phase0-Detect: checking input element...');
      final inputDetect = await waitForElement(
        controller: controller,
        xpath: inputXPath,
        name: name,
        label: 'input element',
      );
      if (inputDetect == null) {
        _log('[Generic:$name] Phase0-Detect ABORT: input element NOT found after retries');
        return SubmissionResult(
          success: false,
          error: 'Input element not found',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      _log('[Generic:$name] Phase0-Detect: input found, tag=${inputDetect['tag']}, editable=${inputDetect['editable']}');

      // Phase 1: 聚焦输入框
      _log('[Generic:$name] Phase1-Focus: focusing input element...');
      final focusStart = DateTime.now();
      final focusJs = '''
        $helpersJS
        $_focusInputJS
        focusInput('${escapeJavaScript(inputXPath)}');
      ''';
      final focusResult = await controller.runJavaScriptReturningResult(focusJs);
      final focusOk = safeParseJsonResult(focusResult);
      final focusMs = DateTime.now().difference(focusStart).inMilliseconds;
      _log('[Generic:$name] Phase1-Focus result (${focusMs}ms): $focusOk');

      if (focusOk == null || focusOk['success'] != true) {
        _log('[Generic:$name] Phase1-Focus: element not found, continuing anyway...');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      // Phase 2: 填充内容
      _log('[Generic:$name] Phase2-Fill: filling input...');
      final fillStart = DateTime.now();
      final fillJs = '''
        $helpersJS
        $_fillInputJS
        fillInput('${escapeJavaScript(inputXPath)}', '${escapeJavaScript(message)}');
      ''';
      final fillResult = await controller.runJavaScriptReturningResult(fillJs);
      final fillOk = safeParseJsonResult(fillResult);
      final fillMs = DateTime.now().difference(fillStart).inMilliseconds;
      _log('[Generic:$name] Phase2-Fill result (${fillMs}ms): $fillOk');

      if (fillOk == null || fillOk['success'] != true) {
        final error = (fillOk?['error'] as String?) ?? 'Fill input failed';
        _log('[Generic:$name] Phase2-Fill FAILED: $error');
        return SubmissionResult(
          success: false,
          error: error,
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      await Future.delayed(const Duration(milliseconds: 1000));

      // Phase 3: 点击发送按钮（含重试验证）
      final clickResult = await submitWithRetry(
        controller: controller,
        inputXPath: inputXPath,
        submitXPath: submitXPath,
        clickJs: '''
          $helpersJS
          $_clickSubmitJS
          clickSubmit('${escapeJavaScript(submitXPath)}');
        ''',
        tabId: tabId,
        displayName: displayName,
      );

      if (clickResult.success) {
        _log('[Generic:$name] Submission succeeded. Injecting answer status observer...');
        await injectAnswerStatusObserverShared(
          controller: controller,
          answerContentXPath: answerContentXPath,
          name: name,
          log: _log,
        );
      }

      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[Generic:$name] ====== STRATEGY END (${totalMs}ms) ======');

      return clickResult;
    } catch (e, stack) {
      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[Generic:$name] EXCEPTION (${totalMs}ms): $e');
      _log('[Generic:$name] Stack: $stack');
      return SubmissionResult(
        success: false,
        error: 'JavaScript execution error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'GenericStrategy', error: error);
  }
}
