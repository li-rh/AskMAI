import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
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
    String tabId,
  ) async {
    try {
      // 1. 聚焦与点击
      final focusJs = '''
        $helpersJS
        $_focusInputJS
        focusInput('${escapeJavaScript(inputXPath)}');
      ''';
      final focusResult = await controller.runJavaScriptReturningResult(focusJs);
      final focusOk = parseResult(focusResult);

      if (focusOk == null || focusOk['success'] != true) {
        // 聚焦失败可以继续尝试，不阻断流程
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // 2. Ctrl+A + Delete 清空输入框
      final clearJs = '''
        $helpersJS
        $_clearInputJS
        clearInput('${escapeJavaScript(inputXPath)}');
      ''';
      await controller.runJavaScriptReturningResult(clearJs);

      await Future.delayed(const Duration(milliseconds: 100));

      // 3. 构造 DataTransfer 并触发 paste 事件
      final pasteJs = '''
        $helpersJS
        $_pasteInputJS
        pasteInput('${escapeJavaScript(inputXPath)}', '${escapeJavaScript(message)}');
      ''';
      final pasteResult = await controller.runJavaScriptReturningResult(pasteJs);
      final pasteOk = parseResult(pasteResult);

      if (pasteOk == null || pasteOk['success'] != true) {
        return SubmissionResult(
          success: false,
          error: (pasteOk?['error'] as String?) ?? 'Paste input failed',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      // 等待粘贴的内容被框架/DOM 识别，同步 UI 状态
      await Future.delayed(const Duration(milliseconds: 500));

      // 4. 点击发送按钮（不使用 Enter 兜底）
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
        error: 'Unexpected result from click step: ${clickResult.runtimeType}',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    } catch (e) {
      return SubmissionResult(
        success: false,
        error: 'ClearAndPasteStrategy error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }
}
