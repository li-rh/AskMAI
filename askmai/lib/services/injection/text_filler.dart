import 'injection_helpers.dart';

/// 文本填充策略接口 — 只负责"如何把文本塞进输入框"
///
/// 每种 Filler 只需实现 [buildFillJs]，返回注入到 WebView 中执行的 JavaScript。
/// Pipeline 负责检测元素、聚焦、提交等公共流程。
abstract class TextFiller {
  /// 策略名称（用于日志和 site_config 配置）
  String get name;

  /// 构建填充文本的 JavaScript 代码。
  ///
  /// 返回的 JS 应定义一个函数并立即调用它，返回 JSON 标式结果：
  /// `{ success: true/false, error: '...', step: 'fill' }`
  String buildFillJs(String inputXPath, String message);

  /// 构建聚焦输入元素的 JavaScript 代码（可选覆盖）。
  String? buildFocusJs(String inputXPath) => null;

  /// 聚焦执行次数。统一为 2 次。
  int get focusAttempts => 2;

  /// 填充后等待时间。统一为 1000ms。
  Duration get fillDelay => const Duration(milliseconds: 1000);

  /// 构建填充前的额外检测 JavaScript 代码（可选覆盖）。
  String? buildPreFillDetectJs(String inputXPath) => null;

  /// 构建预检测的诊断日志 JavaScript 代码（可选覆盖）。
  String? buildPreFillDetectDiagJs(String inputXPath) => null;
}

/// 标准 DOM 输入填充策略（针对 <textarea> 和 <input> 元素）
///
/// 原理：通过 HTMLTextAreaElement / HTMLInputElement 原生 prototype setter
/// 写入值，绕过 React/Vue 的 value 拦截，再触发 input/change 事件同步状态。
class DomInputFiller extends TextFiller {
  @override
  String get name => 'dom_input';

  @override
  String buildFocusJs(String inputXPath) => '''
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

  @override
  String buildFillJs(String inputXPath, String message) => '''
    (function() {
      try {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) {
          return JSON.stringify({ success: false, error: 'Input element not found', step: 'fill' });
        }
        if (el.tagName !== 'TEXTAREA' && el.tagName !== 'INPUT') {
          return JSON.stringify({ success: false, error: 'Element is not a textarea or input (got: ' + el.tagName + ')', step: 'fill' });
        }

        var proto = el.tagName === 'TEXTAREA'
          ? window.HTMLTextAreaElement.prototype
          : window.HTMLInputElement.prototype;
        var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
        setter.call(el, '${escapeJavaScript(message)}');

        el.dispatchEvent(new Event('input',  { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));

        var actual = el.value;
        var prefix = '${escapeJavaScript(message)}'.substring(0, Math.min('${escapeJavaScript(message)}'.length, 5));
        if (!actual || actual.length < '${escapeJavaScript(message)}'.length || !actual.includes(prefix)) {
          return JSON.stringify({ success: false, error: 'Fill verification failed: content not reflected in element value', step: 'fill' });
        }

        return JSON.stringify({ success: true, step: 'fill' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'fill' });
      }
    })()
  ''';
}

/// execCommand insertText 填充策略（针对 contenteditable 元素）
///
/// 适用场景：ChatGPT、Gemini、Kimi 等使用 contenteditable div 的 AI 网站。
/// 利用浏览器原生编辑栈 document.execCommand('insertText') 插入文本。
class ExecCommandFiller extends TextFiller {
  @override
  String get name => 'exec_command';

  @override
  String buildFocusJs(String inputXPath) => '''
    (function() {
      try {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) return JSON.stringify({ success: false, error: 'Element not found', step: 'focus' });
        el.focus();
        _simulateClick(el);
        return JSON.stringify({ success: true, step: 'focus', tagName: el.tagName, isContentEditable: el.isContentEditable });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'focus' });
      }
    })()
  ''';

  @override
  String buildFillJs(String inputXPath, String message) => '''
    (function() {
      try {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) return JSON.stringify({ success: false, error: 'Element not found', step: 'fill' });
        if (!el.isContentEditable && el.contentEditable !== 'true') {
          return JSON.stringify({ success: false, error: 'Element is not contenteditable', step: 'fill' });
        }

        var target = el.querySelector('[contenteditable="true"]') || el;
        var msg = '${escapeJavaScript(message)}';

        target.focus();
        var sel = window.getSelection();
        var rng = document.createRange();
        rng.selectNodeContents(target);
        sel.removeAllRanges();
        sel.addRange(rng);

        if (document.execCommand('insertText', false, msg)) {
          return JSON.stringify({ success: true, method: 'execCommand', step: 'fill' });
        }

        return JSON.stringify({ success: false, error: 'execCommand insertText returned false', step: 'fill' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'fill' });
      }
    })()
  ''';
}

/// InputEvent beforeinput + input 填充策略（针对 contenteditable 元素）
///
/// 适用场景：现代 React contenteditable 应用。
/// 通过派发 InputEvent('beforeinput' + 'input') 绕过 execCommand 兼容性问题。
class InputEventFiller extends TextFiller {
  @override
  String get name => 'input_event';

  @override
  String buildFocusJs(String inputXPath) => '''
    (function() {
      try {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) return JSON.stringify({ success: false, error: 'Element not found', step: 'focus' });
        el.focus();
        _simulateClick(el);
        return JSON.stringify({ success: true, step: 'focus', tagName: el.tagName, isContentEditable: el.isContentEditable });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'focus' });
      }
    })()
  ''';

  @override
  String buildFillJs(String inputXPath, String message) => '''
    (function() {
      try {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) return JSON.stringify({ success: false, error: 'Element not found', step: 'fill' });
        if (!el.isContentEditable && el.contentEditable !== 'true') {
          return JSON.stringify({ success: false, error: 'Element is not contenteditable', step: 'fill' });
        }

        var target = el.querySelector('[contenteditable="true"]') || el;
        var msg = '${escapeJavaScript(message)}';

        target.focus();
        try {
          target.dispatchEvent(new InputEvent('beforeinput', {
            inputType: 'insertText', data: msg, bubbles: true, cancelable: true, composed: true
          }));
          target.dispatchEvent(new InputEvent('input', {
            inputType: 'insertText', data: msg, bubbles: true, composed: true
          }));
        } catch (e) {}

        var tc = (target.textContent || '').trim();
        var prefix = msg.substring(0, Math.min(msg.length, 10));
        if (tc.indexOf(prefix) >= 0) {
          return JSON.stringify({ success: true, method: 'input_event', step: 'fill' });
        }

        return JSON.stringify({ success: false, error: 'InputEvent did not update element text content', step: 'fill' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'fill' });
      }
    })()
  ''';
}

/// ClipboardEvent paste 填充策略（针对 contenteditable 元素）
///
/// 适用场景：需要通过粘贴触发编辑器状态更新的富文本编辑器。
/// 模拟 ClipboardEvent('paste') 将文本粘贴到输入框。
class ClipboardPasteFiller extends TextFiller {
  @override
  String get name => 'clipboard_paste';

  @override
  String buildFocusJs(String inputXPath) => '''
    (function() {
      try {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) return JSON.stringify({ success: false, error: 'Element not found', step: 'focus' });
        el.focus();
        _simulateClick(el);
        return JSON.stringify({ success: true, step: 'focus', tagName: el.tagName, isContentEditable: el.isContentEditable });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'focus' });
      }
    })()
  ''';

  @override
  String buildFillJs(String inputXPath, String message) => '''
    (function() {
      try {
        var el = _findElement('${escapeJavaScript(inputXPath)}');
        if (!el) return JSON.stringify({ success: false, error: 'Element not found', step: 'fill' });
        if (!el.isContentEditable && el.contentEditable !== 'true') {
          return JSON.stringify({ success: false, error: 'Element is not contenteditable', step: 'fill' });
        }

        var target = el.querySelector('[contenteditable="true"]') || el;
        var msg = '${escapeJavaScript(message)}';

        target.focus();
        var dt = new DataTransfer();
        dt.setData('text/plain', msg);
        target.dispatchEvent(new ClipboardEvent('paste', {
          clipboardData: dt, bubbles: true, cancelable: true
        }));
        target.dispatchEvent(new Event('input', { bubbles: true }));
        target.dispatchEvent(new Event('change', { bubbles: true }));

        return JSON.stringify({ success: true, method: 'clipboard_paste', step: 'fill' });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message, step: 'fill' });
      }
    })()
  ''';
}

/// React Fiber + Slate.js 填充策略（针对千问等 React SPA）
///
/// 利用 React Fiber 直接访问 Slate Editor 实例，绕过所有 DOM 拦截。
/// 需要额外的 __reactFiber 和 Slate 检测（通过 [buildPreFillDetectJs]）。
/// 如果未找到 Slate 实例，直接失败（不做标准 input 回退）。
class ReactSlateFiller extends TextFiller {
  @override
  String get name => 'react_slate';

  @override
  String buildFocusJs(String inputXPath) => '''
    (function() {
      var editor = _findElement('${escapeJavaScript(inputXPath)}');
      if (!editor) return JSON.stringify({ success: false, error: 'not_found', step: 'focus' });
      editor.focus();
      _simulateClick(editor);
      return JSON.stringify({ success: true, step: 'focus' });
    })()
  ''';

  @override
  String buildPreFillDetectJs(String inputXPath) => '''
    (function() {
      var input = _findElement('${escapeJavaScript(inputXPath)}');
      if (!input) return JSON.stringify({ hasFiber: false, hasSlate: false });
      var fiberKey = Object.keys(input).find(function(k) { return k.startsWith('__reactFiber'); });
      var hasFiber = !!fiberKey;
      var hasSlate = false;
      if (hasFiber) {
        var fiber = input[fiberKey];
        while (fiber) {
          if (fiber.memoizedProps && fiber.memoizedProps.editor) { hasSlate = true; break; }
          fiber = fiber.return;
        }
      }
      return JSON.stringify({ hasFiber: hasFiber, hasSlate: hasSlate });
    })()
  ''';

  @override
  String? buildPreFillDetectDiagJs(String inputXPath) => '''
    (function() {
      var input = _findElement('${escapeJavaScript(inputXPath)}');
      if (!input) return 'input element not found';
      var fiberKey = Object.keys(input).find(function(k) { return k.startsWith('__reactFiber'); });
      var hasFiber = !!fiberKey;
      var hasSlate = false;
      if (hasFiber) {
        var fiber = input[fiberKey];
        while (fiber) {
          if (fiber.memoizedProps && fiber.memoizedProps.editor) { hasSlate = true; break; }
          fiber = fiber.return;
        }
      }
      var diag = 'hasFiber=' + hasFiber + ', hasSlate=' + hasSlate;
      if (!hasFiber) diag += ' (WARNING: no React Fiber found)';
      if (!hasSlate) diag += ' (WARNING: no Slate editor instance found)';
      return diag;
    })()
  ''';

  @override
  String buildFillJs(String inputXPath, String message) => '''
    (function() {
      try {
        var editor = _findElement('${escapeJavaScript(inputXPath)}');
        if (!editor) return JSON.stringify({ success: false, error: 'Editor element not found', found: false });

        var fiberKey = Object.keys(editor).find(k => k.startsWith('__reactFiber'));
        if (!fiberKey) return JSON.stringify({ success: false, error: 'React Fiber not found (try refreshing the page)', found: true, hasFiber: false });

        var fiber = editor[fiberKey];
        var slateEditor = null;

        while (fiber && !slateEditor) {
            if (fiber.memoizedProps && fiber.memoizedProps.editor) {
                slateEditor = fiber.memoizedProps.editor;
            }
            fiber = fiber.return;
        }

        if (!slateEditor) {
            return JSON.stringify({ success: false, error: 'Slate editor instance not found', found: true, hasFiber: true, hasSlate: false });
        }

        try {
            if (slateEditor.children && slateEditor.children.length > 0) {
                try {
                    slateEditor.select({
                        anchor: slateEditor.start([]),
                        focus: slateEditor.end([])
                    });
                    slateEditor.deleteFragment();
                } catch (selectError) {
                    try {
                        var lastPath = [slateEditor.children.length - 1];
                        var lastNode = slateEditor.children[slateEditor.children.length - 1];
                        var maxDepth = 100;
                        while(lastNode.children) {
                            if (lastNode === lastNode.children || maxDepth-- <= 0) break;
                            lastPath.push(lastNode.children.length - 1);
                            lastNode = lastNode.children[lastNode.children.length - 1];
                        }
                        slateEditor.select({
                            anchor: { path: [0, 0], offset: 0 },
                            focus: { path: lastPath, offset: lastNode.text ? lastNode.text.length : 0 }
                        });
                        slateEditor.deleteFragment();
                    } catch (e2) {
                        console.warn('Slate selection failed, attempting fallback delete');
                    }
                }
            }
        } catch (e) {
            console.error('Slate cleanup error:', e);
        }

        try {
            slateEditor.insertText('${escapeJavaScript(message)}');
        } catch (insertError) {
            return JSON.stringify({ success: false, error: 'Slate insertText failed: ' + insertError.message, found: true, hasFiber: true, hasSlate: true });
        }

        editor.dispatchEvent(new InputEvent('input', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: '${escapeJavaScript(message)}'
        }));

        return JSON.stringify({ success: true, method: 'slate_api', found: true, hasFiber: true, hasSlate: true });
      } catch (e) {
        return JSON.stringify({ success: false, error: e.message });
      }
    })()
  ''';
}
