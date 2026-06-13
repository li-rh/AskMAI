import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import 'injection_strategy.dart';

/// 标准 DOM 输入策略（针对 <textarea> 和 <input> 元素）
///
/// 适用站点：DeepSeek、豆包等使用标准 HTML textarea 的 AI 网站。
/// 原理：通过 HTMLTextAreaElement / HTMLInputElement 原生 prototype setter
/// 写入值，绕过 React/Vue 的 value 拦截，再触发 input/change 事件同步状态。
/// 最后直接 click 发送按钮，不使用 Enter 键兜底（Android WebView 不支持）。
class DomInputStrategy extends InjectionStrategy {
  static const String _fillJS = r'''
    function fillInput(inputSelector, messageText) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input element not found', step: 'fill' });
        }
        if (el.tagName !== 'TEXTAREA' && el.tagName !== 'INPUT') {
          return JSON.stringify({ success: false, error: 'Element is not a textarea or input (got: ' + el.tagName + ')', step: 'fill' });
        }

        // 使用原生 prototype setter 绕过框架的 value 属性拦截
        var proto = el.tagName === 'TEXTAREA'
          ? window.HTMLTextAreaElement.prototype
          : window.HTMLInputElement.prototype;
        var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
        setter.call(el, messageText);

        el.dispatchEvent(new Event('input',  { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));

        // 验证写入结果
        var actual = el.value;
        if (!actual || !actual.includes(messageText.substring(0, Math.min(messageText.length, 10)))) {
          return JSON.stringify({ success: false, error: 'Fill verification failed: content not reflected in element value', step: 'fill' });
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
          return JSON.stringify({ success: false, error: 'Submit button is disabled (input may not have been registered by the framework)', step: 'click' });
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
      // 1. 聚焦输入框
      final focusJs = '''
        $helpersJS
        (function() {
          try {
            var el = _findElement('${escapeJavaScript(inputXPath)}');
            if (!el) return JSON.stringify({ success: false, error: 'Input not found', step: 'focus' });
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

      // 2. 填充内容
      final fillJs = '''
        $helpersJS
        $_fillJS
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
        error: 'DomInputStrategy error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }
}
