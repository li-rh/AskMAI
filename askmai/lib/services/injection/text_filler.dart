import 'injection_helpers.dart';

/// 文本填充策略接口 — 只负责"如何把文本塞进输入框"
///
/// 每种 Filler 只需实现 [buildFillJs]，返回注入到 WebView 中执行的 JavaScript。
/// Pipeline 负责检测元素、聚焦、提交等公共流程。
abstract class TextFiller {
  /// 策略名称（用于日志）
  String get name;

  /// 构建填充文本的 JavaScript 代码。
  ///
  /// 返回的 JS 应定义一个函数并立即调用它，返回 JSON 格式结果：
  /// `{ success: true/false, error: '...', step: 'fill' }`
  ///
  /// [inputXPath] 输入元素的 XPath 或 CSS 选择器
  /// [message] 要填入的文本
  String buildFillJs(String inputXPath, String message);

  /// 构建聚焦输入元素的 JavaScript 代码（可选覆盖）。
  ///
  /// 默认返回 null，Pipeline 使用标准聚焦流程。
  /// ReactFiber 需要双重聚焦序列时覆盖此方法。
  String? buildFocusJs(String inputXPath) => null;

  /// 构建填充前的额外检测 JavaScript 代码（可选覆盖）。
  ///
  /// 默认返回 null，Pipeline 跳过额外检测。
  /// ReactFiber 需要检测 __reactFiber 和 Slate 编辑器时覆盖此方法。
  String? buildPreFillDetectJs(String inputXPath) => null;

  /// 构建预检测的诊断日志 JavaScript 代码（可选覆盖）。
  ///
  /// 默认返回 null，Pipeline 不输出额外诊断。
  /// ReactFiber 覆写此方法以输出 hasFiber/hasSlate 等诊断信息。
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

        // 使用原生 prototype setter 绕过框架的 value 属性拦截
        var proto = el.tagName === 'TEXTAREA'
          ? window.HTMLTextAreaElement.prototype
          : window.HTMLInputElement.prototype;
        var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
        setter.call(el, '${escapeJavaScript(message)}');

        el.dispatchEvent(new Event('input',  { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));

        // 验证写入结果
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

/// ContentEditable 填充策略（针对 div[contenteditable] 元素）
///
/// 适用场景：元宝（Quill 编辑器）、Gemini、ChatGPT、Kimi 等使用 contenteditable div 的 AI 网站。
/// 6 级回退：
///   1. Quill 编辑器 API（__quill.setText + insertText）
///   2. document.execCommand('insertText') — 浏览器原生编辑栈
///   3. InputEvent('beforeinput' + 'input') — 绕过 execCommand 兼容性问题
///   4. ClipboardEvent('paste') — 模拟粘贴行为
///   5. 逐字符键盘事件模拟
///   6. textContent 直接赋值兜底
class ContentEditableFiller extends TextFiller {
  @override
  String get name => 'contenteditable';

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
        if (!el) return JSON.stringify({ success: false, error: 'ContentEditable element not found', step: 'fill' });
        if (!el.isContentEditable && el.contentEditable !== 'true') {
          return JSON.stringify({ success: false, error: 'Element is not contenteditable (got: ' + el.contentEditable + ')', step: 'fill' });
        }

        var target = el.querySelector('[contenteditable="true"]') || el;
        var msg = '${escapeJavaScript(message)}';
        var prefix = msg.substring(0, Math.min(msg.length, 10));

        function _readText(e) {
          var tc = (e.textContent || '').trim();
          return tc.length > 0 ? tc : (e.innerText || '').trim();
        }

        function _check() {
          var t = _readText(target);
          return { ok: t.indexOf(prefix) >= 0, el: target };
        }

        // 方案 1: Quill 编辑器 API 直接注入
        if (target.closest('.ql-editor')) {
          var cand = target.parentElement;
          while (cand && cand !== document.documentElement) {
            if (cand.__quill) {
              try {
                cand.__quill.setText('');
                cand.__quill.insertText(0, msg, 'user');
                return JSON.stringify({ success: true, method: 'quill_api', step: 'fill' });
              } catch (e) { break; }
            }
            cand = cand.parentElement;
          }
        }

        // 方案 2: execCommand insertText
        target.focus();
        var sel = window.getSelection();
        var rng = document.createRange();
        rng.selectNodeContents(target);
        sel.removeAllRanges();
        sel.addRange(rng);
        if (document.execCommand('insertText', false, msg)) {
          return JSON.stringify({ success: true, method: 'execCommand', step: 'fill' });
        }

        // 方案 3: InputEvent insertText
        var vr = _check();
        if (!vr.ok) {
          var cur = vr.el;
          cur.focus();
          try {
            cur.dispatchEvent(new InputEvent('beforeinput', { inputType: 'insertText', data: msg, bubbles: true, cancelable: true, composed: true }));
            cur.dispatchEvent(new InputEvent('input', { inputType: 'insertText', data: msg, bubbles: true, composed: true }));
          } catch(e) {}
          vr = _check();
        }

        // 方案 4: ClipboardEvent paste
        if (!vr.ok) {
          var cur = vr.el;
          cur.focus();
          var dt = new DataTransfer();
          dt.setData('text/plain', msg);
          cur.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
          cur.dispatchEvent(new Event('input', { bubbles: true }));
          cur.dispatchEvent(new Event('change', { bubbles: true }));
          vr = _check();
        }

        // 方案 5: 逐字符键盘事件模拟
        if (!vr.ok) {
          var cur = vr.el;
          cur.focus();
          sel = window.getSelection();
          rng = document.createRange();
          rng.selectNodeContents(cur);
          sel.removeAllRanges();
          sel.addRange(rng);
          for (var ci = 0; ci < msg.length; ci++) {
            var ch = msg[ci];
            cur.dispatchEvent(new KeyboardEvent('keydown', { key: ch, bubbles: true }));
            cur.dispatchEvent(new KeyboardEvent('keypress', { key: ch, bubbles: true }));
            document.execCommand('insertText', false, ch);
            cur.dispatchEvent(new InputEvent('input', { inputType: 'insertText', data: ch, bubbles: true }));
            cur.dispatchEvent(new KeyboardEvent('keyup', { key: ch, bubbles: true }));
          }
          vr = _check();
        }

        // 方案 6: 直接 DOM 赋值最终兜底
        if (!vr.ok) {
          var cur = vr.el;
          cur.textContent = msg;
          cur.dispatchEvent(new Event('input', { bubbles: true }));
          cur.dispatchEvent(new Event('change', { bubbles: true }));
          vr = _check();
        }

        if (!vr.ok) {
          return JSON.stringify({ success: false, error: 'Fill verification failed: text not found in contenteditable element', step: 'fill' });
        }

        return JSON.stringify({ success: true, step: 'fill' });
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
class ReactFiberFiller extends TextFiller {
  @override
  String get name => 'react_fiber';

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
        if (!editor) return JSON.stringify({ success: false, error: '未找到编辑器', found: false });

        var fiberKey = Object.keys(editor).find(k => k.startsWith('__reactFiber'));
        if (!fiberKey) return JSON.stringify({ success: false, error: '未找到 React Fiber (请刷新页面)', found: true, hasFiber: false });

        var fiber = editor[fiberKey];
        var slateEditor = null;

        while (fiber && !slateEditor) {
            if (fiber.memoizedProps && fiber.memoizedProps.editor) {
                slateEditor = fiber.memoizedProps.editor;
            }
            fiber = fiber.return;
        }

        if (!slateEditor) {
            if (editor.tagName === 'TEXTAREA' || editor.tagName === 'INPUT') {
                editor.value = '${escapeJavaScript(message)}';
                editor.dispatchEvent(new Event('input', { bubbles: true }));
                editor.dispatchEvent(new Event('change', { bubbles: true }));
                return JSON.stringify({ success: true, method: 'standard_fallback', found: true, hasFiber: true, hasSlate: false });
            }
            return JSON.stringify({ success: false, error: '未找到 Slate 内部实例且非标准输入框', found: true, hasFiber: true, hasSlate: false });
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
            editor.textContent = '${escapeJavaScript(message)}';
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
