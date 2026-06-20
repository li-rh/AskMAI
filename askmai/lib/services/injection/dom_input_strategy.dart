import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../utils/json_utils.dart';
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
        var prefix = messageText.substring(0, Math.min(messageText.length, 5));
        if (!actual || actual.length < messageText.length || !actual.includes(prefix)) {
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
    String tabId, {
    String? displayName,
  }) async {
    final name = displayName ?? tabId;
    final totalStart = DateTime.now();
    _log('[DomInput:$name] ====== STRATEGY START ====== msg.length=${message.length}');

    try {
      // Phase 0: 元素预检测（含重试）
      _log('[DomInput:$name] Phase0-Detect: checking input element...');
      final inputDetect = await waitForElement(
        controller: controller,
        xpath: inputXPath,
        name: name,
        label: 'input element',
      );
      if (inputDetect == null) {
        _log('[DomInput:$name] Phase0-Detect ABORT: input element NOT found after retries');
        return SubmissionResult(
          success: false,
          error: 'Input element not found',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      _log('[DomInput:$name] Phase0-Detect: input found, tag=${inputDetect['tag']}');

      // Phase 1: 聚焦输入框
      _log('[DomInput:$name] Phase1-Focus: focusing input element...');
      final focusStart = DateTime.now();
      final focusJs = '''
        $helpersJS
        (function() {
          try {
            var el = _findElement('${escapeJavaScript(inputXPath)}');
            if (!el) return JSON.stringify({ success: false, error: 'Input not found', step: 'focus' });
            el.focus();
            _simulateClick(el);
            return JSON.stringify({ success: true, step: 'focus', tagName: el.tagName });
          } catch (e) {
            return JSON.stringify({ success: false, error: e.message, step: 'focus' });
          }
        })()
      ''';
      final focusResult = await controller.runJavaScriptReturningResult(focusJs);
      final focusOk = safeParseJsonResult(focusResult);
      final focusMs = DateTime.now().difference(focusStart).inMilliseconds;
      _log('[DomInput:$name] Phase1-Focus result (${focusMs}ms): $focusOk');

      if (focusOk == null || focusOk['success'] != true) {
        _log('[DomInput:$name] Phase1-Focus: element not found, continuing anyway...');
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Phase 2: 填充内容
      _log('[DomInput:$name] Phase2-Fill: filling input with ${message.length} chars...');
      final fillStart = DateTime.now();
      final fillJs = '''
        $helpersJS
        $_fillJS
        fillInput('${escapeJavaScript(inputXPath)}', '${escapeJavaScript(message)}');
      ''';
      final fillResult = await controller.runJavaScriptReturningResult(fillJs);
      final fillOk = safeParseJsonResult(fillResult);
      final fillMs = DateTime.now().difference(fillStart).inMilliseconds;
      _log('[DomInput:$name] Phase2-Fill result (${fillMs}ms): $fillOk');

      if (fillOk == null || fillOk['success'] != true) {
        final error = (fillOk?['error'] as String?) ?? 'Fill input failed';
        _log('[DomInput:$name] Phase2-Fill FAILED: $error');
        return SubmissionResult(
          success: false,
          error: error,
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      await Future.delayed(const Duration(milliseconds: 400));

      // Phase 3: 点击发送按钮（含重试验证）
      final clickResult = await submitWithRetry(
        controller: controller,
        inputXPath: inputXPath,
        submitXPath: submitXPath,
        clickJs: '''
          $helpersJS
          $_clickJS
          clickSubmit('${escapeJavaScript(submitXPath)}');
        ''',
        tabId: tabId,
        displayName: displayName,
      );

      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[DomInput:$name] ====== STRATEGY END (${totalMs}ms) ======');

      return clickResult;
    } catch (e, stack) {
      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[DomInput:$name] EXCEPTION (${totalMs}ms): $e');
      _log('[DomInput:$name] Stack: $stack');
      return SubmissionResult(
        success: false,
        error: 'DomInputStrategy error: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'DomInputStrategy', error: error);
  }
}
