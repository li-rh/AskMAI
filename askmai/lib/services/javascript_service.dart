import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/exports.dart';

/// JavaScript执行服务 - 处理JS注入和自动化
class JavascriptService {
  // ── 共用工具函数（每次注入都会附带） ──
  static const String _helpersJS = '''
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
      var r = el.getBoundingClientRect();
      var cx = r.left + r.width / 2;
      var cy = r.top + r.height / 2;
      var o = { bubbles: true, cancelable: true, clientX: cx, clientY: cy };
      el.dispatchEvent(new PointerEvent('pointerdown', o));
      el.dispatchEvent(new MouseEvent('mousedown', o));
      el.dispatchEvent(new PointerEvent('pointerup', o));
      el.dispatchEvent(new MouseEvent('mouseup', o));
      el.dispatchEvent(new MouseEvent('click', o));
    }
    function _isDisabled(el) {
      if (el.disabled === true) return true;
      if (el.getAttribute('aria-disabled') === 'true') return true;
      if (el.classList.contains('disabled')) return true;
      return false;
    }
  ''';

  /// 预备步骤：点击并聚焦输入框（对于contentEditable编辑器如千问特别重要）
  static const String _focusInputJS = '''
    function focusInput(inputSelector) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input not found', step: 'focus' });
        }
        // 对于 React/Slate 编辑器（如千问），第一次点击会被编辑器初始化消耗，需做两次
        _simulateClick(el);
        el.focus();
        // 如果编辑器是 contentEditable，尝试用 selection 定位光标
        if (el.isContentEditable || el.contentEditable === 'true') {
          var sel = window.getSelection();
          var rng = document.createRange();
          rng.selectNodeContents(el);
          rng.collapse(false);
          sel.removeAllRanges();
          sel.addRange(rng);
        }
        // 第二次聚焦，确保焦点稳定（Slate.js 等可能在第一次 focus 后 blur）
        el.focus();
        return JSON.stringify({ success: true, step: 'focus' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'focus' });
      }
    }
  ''';

  /// 第一步：填充输入框（同步，立即返回结果）
  static const String _fillInputJS = '''
    function fillInput(inputSelector, messageText) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input not found', step: 'fill' });
        }
        if (el.isContentEditable || el.contentEditable === 'true') {
          el.focus();
          el.textContent = messageText;
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        } else {
          var proto = el.tagName === 'TEXTAREA'
            ? window.HTMLTextAreaElement.prototype
            : window.HTMLInputElement.prototype;
          var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
          setter.call(el, messageText);
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }
        return JSON.stringify({ success: true, step: 'fill' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'fill' });
      }
    }
  ''';

  /// 第二步：点击提交按钮
  static const String _clickSubmitJS = '''
    function clickSubmit(submitSelector) {
      try {
        var btn = _findElement(submitSelector);
        if (!btn) {
          // 按钮未找到，尝试对当前焦点元素发送 Enter
          var ae = document.activeElement;
          if (ae) {
            ae.dispatchEvent(new KeyboardEvent('keydown', {
              key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
              bubbles: true, cancelable: true
            }));
            ae.dispatchEvent(new KeyboardEvent('keyup', {
              key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
              bubbles: true, cancelable: true
            }));
            return JSON.stringify({ success: true, method: 'enter' });
          }
          return JSON.stringify({ success: false, error: 'Submit button not found', step: 'click' });
        }
        if (_isDisabled(btn)) {
          // 按钮仍 disabled，用 Enter 兜底
          var ae = document.activeElement;
          if (ae) {
            ae.dispatchEvent(new KeyboardEvent('keydown', {
              key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
              bubbles: true, cancelable: true
            }));
            ae.dispatchEvent(new KeyboardEvent('keyup', {
              key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
              bubbles: true, cancelable: true
            }));
            return JSON.stringify({ success: true, method: 'enter_fallback' });
          }
          return JSON.stringify({ success: false, error: 'Submit button is disabled', step: 'click' });
        }
        _simulateClick(btn);
        if (typeof btn.click === 'function') {
          btn.click();
        }
        return JSON.stringify({ success: true, method: 'click' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'click' });
      }
    }
  ''';

  /// 执行表单提交操作 — 分两步：先填输入，延迟等按钮激活后再点击
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId,
  ) async {
    try {
      // ── 第〇步：聚焦输入框（对 contentEditable 编辑器如千问尤为重要） ──
      final focusJs = '''
        $_helpersJS
        $_focusInputJS
        focusInput('${_escapeJavaScript(inputXPath)}');
      ''';
      final focusResult = await controller.runJavaScriptReturningResult(focusJs);
      final focusOk = _parseResult(focusResult);

      if (focusOk == null || focusOk['success'] != true) {
        print('Warning: Focus step failed for $tabId: ${focusOk?['error']}');
        // 继续执行，不阻塞
      }

      // 等待 React/Slate 编辑器完成合成事件初始化
      await Future.delayed(const Duration(milliseconds: 300));

      // ── 第一步：填充输入框 ──
      final fillJs = '''
        $_helpersJS
        $_fillInputJS
        fillInput('${_escapeJavaScript(inputXPath)}', '${_escapeJavaScript(message)}');
      ''';
      final fillResult = await controller.runJavaScriptReturningResult(fillJs);
      final fillOk = _parseResult(fillResult);

      if (fillOk == null || fillOk['success'] != true) {
        return SubmissionResult(
          success: false,
          error: (fillOk?['error'] as String?) ?? 'Fill input failed',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      // ── 等待 React/Slate/Vue 完成状态更新（按钮从 disabled → enabled） ──
      await Future.delayed(const Duration(milliseconds: 500));

      // ── 第二步：点击提交按钮 ──
      final clickJs = '''
        $_helpersJS
        $_clickSubmitJS
        clickSubmit('${_escapeJavaScript(submitXPath)}');
      ''';
      final clickResult = await controller.runJavaScriptReturningResult(clickJs);
      final clickOk = _parseResult(clickResult);

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

  /// 获取页面中的文本内容
  Future<String?> getPageContent(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(
        'document.body.innerText;',
      );
      return result is String ? result : null;
    } catch (e) {
      return null;
    }
  }

  /// 滚动到底部
  Future<void> scrollToBottom(WebViewController controller) async {
    try {
      await controller.runJavaScriptReturningResult(
        'window.scrollTo(0, document.body.scrollHeight);',
      );
    } catch (e) {
      // 忽略滚动错误
    }
  }

  /// 应用虚拟显示设置 - 通过CSS transform平移内容并调整页面高度
  Future<Map<String, dynamic>?> applyVirtualDisplay(
    WebViewController controller, {
    required double topGap,
    required double bottomGap,
  }) async {
    try {
      // 使用CSS transform来平移内容，同时调整html/body的高度来欺骗页面
      final js = '''
        (function() {
          try {
            var body = document.body;
            var html = document.documentElement;
            var totalGap = ${topGap.toInt()} + ${bottomGap.toInt()};
            
            // 如果总间距为0，移除所有transform样式
            if (totalGap === 0) {
              body.style.transform = '';
              body.style.transformOrigin = '';
              body.style.marginTop = '';
              body.style.marginBottom = '';
              html.style.minHeight = '';
              // 尝试移除可能存在的padding
              var existingStyle = document.getElementById('_virtualDisplayStyle');
              if (existingStyle) existingStyle.remove();
              return JSON.stringify({ success: true, method: 'reset' });
            }
            
            // 添加内联样式来创建虚拟显示效果
            var translateY = -${topGap.toInt()};
            body.style.transform = 'translateY(' + translateY + 'px)';
            body.style.transformOrigin = 'top left';
            
            // 增加页面总高度来补偿平移
            var currentHeight = Math.max(
              body.scrollHeight, 
              html.scrollHeight,
              window.innerHeight
            );
            html.style.minHeight = (currentHeight + totalGap) + 'px';
            
            return JSON.stringify({ 
              success: true, 
              method: 'transform',
              translateY: translateY,
              totalGap: totalGap 
            });
          } catch (e) {
            return JSON.stringify({ success: false, error: e.message });
          }
        })();
      ''';
      final result = await controller.runJavaScriptReturningResult(js);
      return _parseResult(result);
    } catch (e) {
      debugPrint('[JavascriptService] applyVirtualDisplay error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 解析 runJavaScriptReturningResult 的返回值（处理 Android 双重 JSON 编码）
  Map<String, dynamic>? _parseResult(dynamic rawResult) {
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
  static String _escapeJavaScript(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  @override
  String toString() => 'JavascriptService()';
}
