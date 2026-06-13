import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import 'injection_strategy.dart';

/// ContentEditable 注入策略（针对 div[contenteditable] 元素）
///
/// 适用站点：元宝（Quill 编辑器）、Kimi 等使用 contenteditable div 的 AI 网站。
/// 原理：
///   1. 优先使用 document.execCommand('insertText') — 触发浏览器原生编辑栈，
///      框架可感知此事件，是最兼容的方式。
///   2. 若 execCommand 失败（部分 Android WebView 版本不支持），
///      回退到 ClipboardEvent('paste') — 模拟粘贴行为。
///   3. 最终通过 textContent 验证写入是否成功，失败则报错（不误报成功）。
///   4. 直接 click 发送按钮，不使用 Enter 键兜底（Android WebView 不支持）。
class ContentEditableStrategy extends InjectionStrategy {
  static const String _fillJS = r'''
    function fillContentEditable(inputSelector, messageText) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'ContentEditable element not found', step: 'fill' });
        }
        if (!el.isContentEditable && el.contentEditable !== 'true') {
          return JSON.stringify({ success: false, error: 'Element is not contenteditable (got: ' + el.contentEditable + ')', step: 'fill' });
        }

        // 聚焦并将光标移至末尾
        el.focus();
        var sel = window.getSelection();
        var rng = document.createRange();
        rng.selectNodeContents(el);
        sel.removeAllRanges();
        sel.addRange(rng);

        // 尝试方案 1: execCommand insertText（最佳兼容性）
        var ok = document.execCommand('insertText', false, messageText);

        // 尝试方案 2: ClipboardEvent paste（execCommand 不可用时）
        if (!ok) {
          var dt = new DataTransfer();
          dt.setData('text/plain', messageText);
          el.dispatchEvent(new ClipboardEvent('paste', {
            clipboardData: dt,
            bubbles: true,
            cancelable: true
          }));
          el.dispatchEvent(new Event('input', { bubbles: true }));
        }

        // 验证写入结果（取前10个字符防止截断问题）
        var actual = el.textContent || '';
        var prefix = messageText.substring(0, Math.min(messageText.length, 10));
        if (prefix.length > 0 && !actual.includes(prefix)) {
          return JSON.stringify({ success: false, error: 'Fill verification failed: text not found in contenteditable element', step: 'fill' });
        }

        return JSON.stringify({ success: true, step: 'fill' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'fill' });
      }
    }
  ''';

  static const String _clickJS = r'''
    function clickSubmit(submitSelector) {
      try {
        var btn = _findElement(submitSelector);
        if (!btn) {
          return JSON.stringify({ success: false, error: 'Submit button not found', step: 'click' });
        }
        if (_isDisabled(btn)) {
          return JSON.stringify({ success: false, error: 'Submit button is disabled (contenteditable fill may not have been recognized by the framework)', step: 'click' });
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
      // 1. 聚焦并准备光标
      final focusJs = '''
        $helpersJS
        (function() {
          try {
            var el = _findElement('${escapeJavaScript(inputXPath)}');
            if (!el) return JSON.stringify({ success: false, error: 'Element not found', step: 'focus' });
            el.focus();
            _simulateClick(el);
            return JSON.stringify({ success: true, step: 'focus' });
          } catch (e) {
            return JSON.stringify({ success: false, error: e.message, step: 'focus' });
          }
        })()
      ''';
      await controller.runJavaScriptReturningResult(focusJs);
      await Future.delayed(const Duration(milliseconds: 200));

      // 2. 填充 contenteditable
      final fillJs = '''
        $helpersJS
        $_fillJS
        fillContentEditable('${escapeJavaScript(inputXPath)}', '${escapeJavaScript(message)}');
      ''';
      final fillResult = await controller.runJavaScriptReturningResult(fillJs);
      final fillOk = parseResult(fillResult);

      if (fillOk == null || fillOk['success'] != true) {
        return SubmissionResult(
          success: false,
          error: (fillOk?['error'] as String?) ?? 'ContentEditable fill failed',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      await Future.delayed(const Duration(milliseconds: 400));

      // 3. 点击发送按钮
      final clickJs = '''
        $helpersJS
        $_clickJS
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
        error: 'ContentEditableStrategy error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }
}
