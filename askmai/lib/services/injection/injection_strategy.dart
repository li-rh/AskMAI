import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';

/// 注入策略的基类
abstract class InjectionStrategy {
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId,
  );

  /// 解析 runJavaScriptReturningResult 的返回值（处理 Android 双重 JSON 编码）
  Map<String, dynamic>? parseResult(dynamic rawResult) {
    if (rawResult is Map) {
      return rawResult.map((k, v) => MapEntry(k.toString(), v));
    }
    if (rawResult is String && rawResult.isNotEmpty) {
      try {
        dynamic parsed = jsonDecode(rawResult);
        if (parsed is String) {
          parsed = jsonDecode(parsed);
        }
        if (parsed is Map) {
          return (parsed).map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
    return null;
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
    function _isDisabled(el) {
      if (el.disabled === true) return true;
      if (el.getAttribute('aria-disabled') === 'true') return true;
      if (el.classList.contains('disabled')) return true;
      return false;
    }
  ''';
}
