import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import 'injection_strategy.dart';

/// @deprecated 已拆分为更专注的独立策略，此类仅供向后兼容。
/// 请迁移到：
///   - [DomInputStrategy]       → strategy: "dom_input"      (textarea/input)
///   - [ContentEditableStrategy] → strategy: "contenteditable" (div[contenteditable])
///   - [ClearAndPasteStrategy]  → strategy: "clear_and_paste" (粘贴注入)
///   - [ReactFiberStrategy]     → strategy: "react_fiber"     (React + Slate.js SPA)
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
    String tabId,
  ) async {
    try {
      final focusJs = '''
        $helpersJS
        $_focusInputJS
        focusInput('${escapeJavaScript(inputXPath)}');
      ''';
      final focusResult = await controller.runJavaScriptReturningResult(focusJs);
      final focusOk = parseResult(focusResult);

      if (focusOk == null || focusOk['success'] != true) {
        // 聚焦失败可继续，不阻断
      }

      await Future.delayed(const Duration(milliseconds: 300));

      final fillJs = '''
        $helpersJS
        $_fillInputJS
        fillInput('${escapeJavaScript(inputXPath)}', '${escapeJavaScript(message)}');
      ''';
      final fillResult = await controller.runJavaScriptReturningResult(fillJs);
      final fillOk = parseResult(fillResult);

      if (fillOk == null || fillOk['success'] != true) {
        return SubmissionResult(
          success: false,
          error: (fillOk?['error'] as String?) ?? 'Fill input failed',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final clickJs = '''
        $helpersJS
        $_clickSubmitJS
        clickSubmit('${escapeJavaScript(submitXPath)}');
      ''';
      final clickResult = await controller.runJavaScriptReturningResult(clickJs);
      final clickOk = parseResult(clickResult);

      if (clickOk != null) {
        return SubmissionResult(
          success: clickOk['success'] as bool? ?? false,
          error: clickOk['error'] as String?,
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      return SubmissionResult(
        success: false,
        error: 'Unexpected click result type: ${clickResult.runtimeType}',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    } catch (e) {
      return SubmissionResult(
        success: false,
        error: 'JavaScript execution error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }
}
