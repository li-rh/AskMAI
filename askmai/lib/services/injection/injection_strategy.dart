import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../utils/json_utils.dart';

/// 注入策略的基类
abstract class InjectionStrategy {
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId, {
    String? displayName,
  });

  /// 等待元素出现在页面上，最多重试 [maxRetries] 次，每次间隔 [intervalMs] 毫秒
  ///
  /// 返回 `{ found: true/false, tag: '...', ... }` 最后一次检测结果
  Future<Map<String, dynamic>?> waitForElement({
    required WebViewController controller,
    required String xpath,
    required String name,
    String label = 'element',
    int maxRetries = 5,
    int intervalMs = 200,
  }) async {
    final detectJs = '''
      $helpersJS
      (function() {
        var el = _findElement('${escapeJavaScript(xpath)}');
        if (!el) return JSON.stringify({ found: false });
        return JSON.stringify({ found: true, tag: el.tagName, editable: el.isContentEditable || el.contentEditable === 'true' });
      })()
    ''';
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await controller.runJavaScriptReturningResult(detectJs);
      final parsed = safeParseJsonResult(result);

      if (parsed != null && parsed['found'] == true) {
        if (attempt > 1) {
          _log('[$name] $label found on attempt $attempt');
        }
        return parsed;
      }

      if (attempt < maxRetries) {
        _log('[$name] $label not found, retry $attempt/$maxRetries: waiting ${intervalMs}ms...');
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
    }

    _log('[$name] $label NOT found after $maxRetries retries');
    return null;
  }

  /// 统一的发送按钮提交流程：预检测 → 点击 → 重试验证
  ///
  /// 流程：
  /// 1. 预检测按钮是否存在及是否禁用
  /// 2. 执行点击 JS
  /// 3. 点击后验证输入框是否还有内容，有则重试，最多 [maxRetries] 次
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
  }) async {
    final name = displayName ?? tabId;

    // Phase A: 预检测按钮（统一循环）
    final preCheckJs = '''
      $helpersJS
      (function() {
        var btn = _findElement('${escapeJavaScript(submitXPath)}');
        ${fallbackSubmitXPath != null ? "if (!btn) btn = document.querySelector('${escapeJavaScript(fallbackSubmitXPath)}');" : ''}
        return JSON.stringify({
          found: !!btn,
          tag: btn ? btn.tagName : null,
          disabled: btn ? _isDisabled(btn) : null
        });
      })()
    ''';
    var buttonReady = false;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final preCheckResult = await controller.runJavaScriptReturningResult(preCheckJs);
      final preCheckOk = safeParseJsonResult(preCheckResult);
      _log('[$name] Submit pre-check attempt $attempt: found=${preCheckOk?['found']}, tag=${preCheckOk?['tag']}, disabled=${preCheckOk?['disabled']}');

      if (preCheckOk?['found'] == true && preCheckOk?['disabled'] != true) {
        _log('[$name] Submit button is ready');
        buttonReady = true;
        break;
      }

      if (attempt < maxRetries) {
        final reason = preCheckOk?['found'] != true ? 'not found' : 'disabled';
        _log('[$name] Submit $reason, retry $attempt/$maxRetries: waiting 200ms...');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    if (!buttonReady) {
      _log('[$name] Submit ABORT: button not ready after $maxRetries retries');
      return SubmissionResult(
        success: false,
        error: 'Submit button not ready after $maxRetries retries',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }

    // Phase B+C: 点击 + 验证循环（先点击再检测）
    final verifyJs = '''
      $helpersJS
      (function() {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) return JSON.stringify({ hasContent: false, found: false });
        var hasContent = (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT')
          ? el.value.length > 0
          : el.textContent.trim().length > 0;
        return JSON.stringify({ hasContent: hasContent, found: true });
      })()
    ''';
    // 将 fallback 注入 click JS（替换 _findElement 为带 fallback 的 _findSubmitButton）
    final resolvedClickJs = clickFallbackSelector != null
        ? clickJs.replaceAll(
            "_findElement('${escapeJavaScript(submitXPath)}')",
            "_findSubmitButton('${escapeJavaScript(submitXPath)}', '${escapeJavaScript(clickFallbackSelector)}')",
          )
        : clickJs;

    var clickOk = <String, dynamic>{'success': false};
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final clickStart = DateTime.now();
      final clickResult = await controller.runJavaScriptReturningResult(resolvedClickJs);
      clickOk = safeParseJsonResult(clickResult) ?? clickOk;
      final clickMs = DateTime.now().difference(clickStart).inMilliseconds;
      _log('[$name] Submit click attempt $attempt (${clickMs}ms): $clickOk');

      await Future.delayed(const Duration(milliseconds: 200));

      final verifyResult = await controller.runJavaScriptReturningResult(verifyJs);
      final verifyOk = safeParseJsonResult(verifyResult);

      if (verifyOk == null || verifyOk['hasContent'] != true) {
        _log('[$name] Submit verify: input is empty, click succeeded');
        if (clickOk['success'] != true) {
          clickOk = {'success': true, 'error': null, 'step': 'verify'};
        }
        break;
      }

      _log('[$name] Submit retry $attempt/$maxRetries: input still has content');
    }

    return SubmissionResult(
      success: clickOk['success'] == true,
      error: clickOk['error'] as String?,
      timestamp: DateTime.now(),
      tabId: tabId,
    );
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: runtimeType.toString(), error: error);
  }

  /// 转义JavaScript中的特殊字符
  String escapeJavaScript(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// 共用的 DOM 查询与点击工具函数
  String get helpersJS => '''
    function _findElement(selector) {
      if (!selector) return null;
      if (selector.startsWith('//') || selector.startsWith('/')) {
        return document.evaluate(
          selector, document, null,
          XPathResult.FIRST_ORDERED_NODE_TYPE, null
        ).singleNodeValue;
      }
      return document.querySelector(selector);
    }
    function _simulateClick(el) {
      if (!el) return;
      var r = el.getBoundingClientRect();
      var cx = r.left + r.width / 2;
      var cy = r.top + r.height / 2;
      var o = { bubbles: true, cancelable: true, clientX: cx, clientY: cy };
      
      // 移动端 Touch 事件分发
      if (window.TouchEvent) {
        try {
          var touch = new Touch({
            identifier: Date.now(),
            target: el,
            clientX: cx,
            clientY: cy,
            screenX: cx,
            screenY: cy,
            pageX: cx,
            pageY: cy
          });
          var touchOpts = { 
            bubbles: true, 
            cancelable: true, 
            touches: [touch], 
            targetTouches: [touch], 
            changedTouches: [touch] 
          };
          el.dispatchEvent(new TouchEvent('touchstart', touchOpts));
          el.dispatchEvent(new TouchEvent('touchend', touchOpts));
        } catch (e) {
          el.dispatchEvent(new Event('touchstart', o));
          el.dispatchEvent(new Event('touchend', o));
        }
      } else {
        el.dispatchEvent(new Event('touchstart', o));
        el.dispatchEvent(new Event('touchend', o));
      }
      
      el.dispatchEvent(new PointerEvent('pointerdown', o));
      el.dispatchEvent(new MouseEvent('mousedown', o));
      el.dispatchEvent(new PointerEvent('pointerup', o));
      el.dispatchEvent(new MouseEvent('mouseup', o));
      el.dispatchEvent(new MouseEvent('click', o));
    }
    function _simulateSubmit(el) {
      if (!el) return;
      _simulateClick(el);
      try {
        if (el.__vue__ || el._vnode) {
          if (el.__vue__ && el.__vue__.\$emit) {
            el.__vue__.\$emit('click');
          }
          if (el._vnode && el._vnode.props && el._vnode.props.onClick) {
            el._vnode.props.onClick();
          }
        }
      } catch (e) {
        console.warn('Vue bypass event failed:', e);
      }
    }
    function _findSubmitButton(primarySelector, fallbackSelector) {
      var btn = _findElement(primarySelector);
      if (!btn && fallbackSelector) btn = document.querySelector(fallbackSelector);
      return btn;
    }
    function _isDisabled(el) {
      if (el.disabled === true) return true;
      if (el.getAttribute('aria-disabled') === 'true') return true;
      if (el.classList.contains('disabled')) return true;
      return false;
    }
  ''';
}
