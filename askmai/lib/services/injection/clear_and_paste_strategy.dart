import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../utils/json_utils.dart';
import 'injection_strategy.dart';

/// 清空并粘贴策略（第三种填充方式）
///
/// 适用场景：输入框内容残留导致 dom_input / contenteditable 策略无法清除旧内容时，
/// 先模拟 Ctrl+A + Delete 全选清空，再通过 ClipboardEvent('paste') 注入新内容。
/// 不使用 Enter 键兜底（Android WebView 不支持）。
class ClearAndPasteStrategy extends InjectionStrategy {
  static const String _focusInputJS = r'''
    function focusInput(inputSelector) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input not found', step: 'focus' });
        }
        el.focus();
        _simulateClick(el);
        return JSON.stringify({ success: true, step: 'focus' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'focus' });
      }
    }
  ''';

  static const String _clearInputJS = r'''
    function clearInput(inputSelector) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input not found', step: 'clear' });
        }
        el.dispatchEvent(new KeyboardEvent('keydown', { key: 'a', ctrlKey: true, bubbles: true }));
        el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Delete', bubbles: true }));
        return JSON.stringify({ success: true, step: 'clear' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'clear' });
      }
    }
  ''';

  static const String _pasteInputJS = r'''
    function pasteInput(inputSelector, messageText) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input not found', step: 'paste' });
        }
        var clipboardData = new DataTransfer();
        clipboardData.setData('text/plain', messageText);
        var pasteEvent = new ClipboardEvent('paste', {
          clipboardData: clipboardData,
          bubbles: true,
          cancelable: true
        });
        el.dispatchEvent(pasteEvent);
        el.dispatchEvent(new Event('input',  { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        return JSON.stringify({ success: true, step: 'paste' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'paste' });
      }
    }
  ''';

  static const String _clickSubmitJS = r'''
    function clickSubmit(submitSelector) {
      try {
        var btn = _findElement(submitSelector);
        if (!btn) {
          return JSON.stringify({ success: false, error: 'Submit button not found', step: 'click' });
        }
        if (_isDisabled(btn)) {
          return JSON.stringify({ success: false, error: 'Submit button is disabled (paste may not have been recognized by the framework)', step: 'click' });
        }
        _simulateSubmit(btn);
        return JSON.stringify({ success: true, method: 'click', step: 'click' });
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
  }) async {
    final name = displayName ?? tabId;
    final totalStart = DateTime.now();
    _log('[ClearPaste:$name] ====== STRATEGY START ====== msg.length=${message.length}');

    try {
      // Phase 0: 元素预检测（含重试）
      _log('[ClearPaste:$name] Phase0-Detect: checking input element...');
      final inputDetect = await waitForElement(
        controller: controller,
        xpath: inputXPath,
        name: name,
        label: 'input element',
      );
      if (inputDetect == null) {
        _log('[ClearPaste:$name] Phase0-Detect ABORT: input element NOT found after retries');
        return SubmissionResult(
          success: false,
          error: 'Input element not found',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      _log('[ClearPaste:$name] Phase0-Detect: input found, tag=${inputDetect['tag']}');

      // Phase 1: 聚焦与点击
      _log('[ClearPaste:$name] Phase1-Focus: focusing input element...');
      final focusStart = DateTime.now();
      final focusJs = '''
        $helpersJS
        $_focusInputJS
        focusInput('${escapeJavaScript(inputXPath)}');
      ''';
      final focusResult = await controller.runJavaScriptReturningResult(focusJs);
      final focusOk = safeParseJsonResult(focusResult);
      final focusMs = DateTime.now().difference(focusStart).inMilliseconds;
      _log('[ClearPaste:$name] Phase1-Focus result (${focusMs}ms): $focusOk');

      if (focusOk == null || focusOk['success'] != true) {
        _log('[ClearPaste:$name] Phase1-Focus: element not found, continuing anyway...');
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Phase 2: Ctrl+A + Delete 清空输入框
      _log('[ClearPaste:$name] Phase2-Clear: clearing input...');
      final clearStart = DateTime.now();
      final clearJs = '''
        $helpersJS
        $_clearInputJS
        clearInput('${escapeJavaScript(inputXPath)}');
      ''';
      final clearResult = await controller.runJavaScriptReturningResult(clearJs);
      final clearMs = DateTime.now().difference(clearStart).inMilliseconds;
      _log('[ClearPaste:$name] Phase2-Clear result (${clearMs}ms): $clearResult');

      await Future.delayed(const Duration(milliseconds: 100));

      // Phase 3: 构造 DataTransfer 并触发 paste 事件
      _log('[ClearPaste:$name] Phase3-Paste: pasting ${message.length} chars...');
      final pasteStart = DateTime.now();
      final pasteJs = '''
        $helpersJS
        $_pasteInputJS
        pasteInput('${escapeJavaScript(inputXPath)}', '${escapeJavaScript(message)}');
      ''';
      final pasteResult = await controller.runJavaScriptReturningResult(pasteJs);
      final pasteOk = safeParseJsonResult(pasteResult);
      final pasteMs = DateTime.now().difference(pasteStart).inMilliseconds;
      _log('[ClearPaste:$name] Phase3-Paste result (${pasteMs}ms): $pasteOk');

      if (pasteOk == null || pasteOk['success'] != true) {
        final error = (pasteOk?['error'] as String?) ?? 'Paste input failed';
        _log('[ClearPaste:$name] Phase3-Paste FAILED: $error');
        return SubmissionResult(
          success: false,
          error: error,
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Phase 4: 点击发送按钮（含重试验证）
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

      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[ClearPaste:$name] ====== STRATEGY END (${totalMs}ms) ======');

      return clickResult;
    } catch (e, stack) {
      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[ClearPaste:$name] EXCEPTION (${totalMs}ms): $e');
      _log('[ClearPaste:$name] Stack: $stack');
      return SubmissionResult(
        success: false,
        error: 'ClearAndPasteStrategy error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'ClearAndPasteStrategy', error: error);
  }
}
