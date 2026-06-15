import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import 'injection_strategy.dart';

/// ContentEditable 注入策略（针对 div[contenteditable] 元素）
///
/// 适用站点：元宝（Quill 编辑器）、Gemini、ChatGPT 等使用 contenteditable div 的 AI 网站。
/// 原理：
///   1. 若有 Quill 实例 (__quill)，优先使用 quill.setText() + quill.insertText() 保证框架同步。
///   2. 否则使用 document.execCommand('insertText')（同 generic 策略的核心逻辑），
///      触发浏览器原生编辑栈，框架可感知此事件。
///   3. 若 execCommand 失败，回退到 ClipboardEvent('paste') — 模拟粘贴行为。
///   4. 最终通过 textContent 直接赋值兜底。
///   5. 直接 click 发送按钮，不使用 Enter 键兜底（Android WebView 不支持）。
///
/// 注意：Android WebView 不支持 sel.insertText()（报错 "is not a function"），
/// 故不走 Selection API deleteFromDocument + insertText 路径。
/// deleteFromDocument 对 Quill 有副作用（触发 reconciliation 导致内容错乱）。
class ContentEditableStrategy extends InjectionStrategy {
  static const String _fillJS = r'''
    function fillContentEditable(inputSelector, messageText) {
      try {
        var el = _findElement(inputSelector);
        if (!el) {
          console.log('[AMAI] fillContentEditable: element not found for selector=' + inputSelector);
          return JSON.stringify({ success: false, error: 'ContentEditable element not found', step: 'fill' });
        }
        if (!el.isContentEditable && el.contentEditable !== 'true') {
          console.log('[AMAI] fillContentEditable: not contenteditable, isContentEditable=' + el.isContentEditable + ' contentEditable=' + el.contentEditable);
          return JSON.stringify({ success: false, error: 'Element is not contenteditable (got: ' + el.contentEditable + ')', step: 'fill' });
        }

        // 定位到最深层的 contenteditable 子元素（编辑器可能在内层子元素中管理状态）
        var inner = el.querySelector('[contenteditable="true"]');
        var target = inner || el;
        console.log('[AMAI] fillContentEditable: el.tagName=' + el.tagName + ' el.className=' + (el.className || '') + ' inner=' + (inner ? inner.tagName : 'null') + ' target=' + target.tagName);

        // 聚焦并将光标移至末尾
        target.focus();
        var sel = window.getSelection();
        var rng = document.createRange();
        rng.selectNodeContents(target);
        sel.removeAllRanges();
        sel.addRange(rng);

        // 方案 1: Quill 编辑器 API 直接注入（最可靠）
        // Quill 将内部实例 (__quill) 附着在 .ql-container 上，而非 .ql-editor 上。
        // 部分站点（如元宝）自定义了 wrapper class，故遍历全部祖先链查找 __quill
        var quillRoot = null;
        if (target.closest('.ql-editor')) {
          var cand = target.parentElement;
          while (cand && cand !== document.documentElement) {
            if (cand.__quill) { quillRoot = cand; break; }
            cand = cand.parentElement;
          }
        }
        console.log('[AMAI] Method1(Quill): found=' + (quillRoot ? 'yes' : 'no') + ' __quill=' + (quillRoot ? (quillRoot.__quill ? 'exists' : 'undefined') : 'n/a'));
        if (quillRoot && quillRoot.__quill) {
          try {
            var quill = quillRoot.__quill;
            console.log('[AMAI] Method1(Quill) taken: textLen=' + messageText.length);
            quill.setText('');
            quill.insertText(0, messageText, 'user');
            console.log('[AMAI] Method1(Quill) success');
            return JSON.stringify({ success: true, method: 'quill_api', step: 'fill' });
          } catch (qe) {
            console.log('[AMAI] Method1(Quill) ERROR: ' + qe.message);
          }
        } else {
          console.log('[AMAI] Method1(Quill) skipped');
        }

        // 方案 2: execCommand insertText — 触发浏览器原生编辑栈，
        // 框架（Quill/ProseMirror）可感知此事件，是最兼容的方式。
        // 注意：sel.insertText 在 Android WebView 中不支持（报错 "is not a function"），
        // 故不采用 Selection API，直接使用 execCommand（与 generic 策略一致）。
        console.log('[AMAI] Method2(execCommand) trying' + (target.closest('.ql-editor') ? ' (quill editor)' : ''));
        target.focus();
        sel = window.getSelection();
        rng = document.createRange();
        rng.selectNodeContents(target);
        sel.removeAllRanges();
        sel.addRange(rng);
        var execOk = document.execCommand('insertText', false, messageText);
        console.log('[AMAI] Method2(execCommand) execOk=' + execOk);

        // 验证写入结果（取前10个字符防止截断问题）
        var actual = target.textContent || '';
        var prefix = messageText.substring(0, Math.min(messageText.length, 10));
        console.log('[AMAI] Verification after M2: prefix="' + prefix + '" found=' + actual.includes(prefix) + ' actualLen=' + actual.length);
        if (prefix.length > 0 && !actual.includes(prefix)) {
          // 方案 3: ClipboardEvent paste 兜底
          console.log('[AMAI] Method3(ClipboardEvent) trying');
          target.focus();
          var dt = new DataTransfer();
          dt.setData('text/plain', messageText);
          target.dispatchEvent(new ClipboardEvent('paste', {
            clipboardData: dt,
            bubbles: true,
            cancelable: true
          }));
          target.dispatchEvent(new Event('input', { bubbles: true }));
          target.dispatchEvent(new Event('change', { bubbles: true }));
          actual = target.textContent || '';
          console.log('[AMAI] Method3(ClipboardEvent) after: found=' + actual.includes(prefix) + ' actualLen=' + actual.length);
        } else {
          console.log('[AMAI] Method3(ClipboardEvent) skipped');
        }

        if (prefix.length > 0 && !actual.includes(prefix)) {
          // 方案 4: 直接 DOM 赋值最终兜底
          console.log('[AMAI] Method4(DOM) trying');
          target.textContent = messageText;
          target.dispatchEvent(new Event('input',  { bubbles: true }));
          target.dispatchEvent(new Event('change', { bubbles: true }));
          actual = target.textContent || '';
          console.log('[AMAI] Method4(DOM) after: found=' + actual.includes(prefix) + ' actualLen=' + actual.length);
          if (prefix.length > 0 && !actual.includes(prefix)) {
            console.log('[AMAI] Method4(DOM) FAILED');
            return JSON.stringify({ success: false, error: 'Fill verification failed: text not found in contenteditable element', step: 'fill' });
          }
          console.log('[AMAI] Method4(DOM) success');
        } else {
          console.log('[AMAI] Method4(DOM) skipped');
        }

        console.log('[AMAI] fillContentEditable overall success');
        return JSON.stringify({ success: true, step: 'fill' });
      } catch (e) {
        console.log('[AMAI] fillContentEditable UNCAUGHT ERROR: ' + e.message);
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
      debugPrint('[ContentEditable] tabId=$tabId fillResult=$fillOk');

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
