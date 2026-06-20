import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../utils/json_utils.dart';
import 'injection_strategy.dart';

/// React Fiber + Slate.js 注入策略（针对千问等 React SPA）
/// 利用 React Fiber 直接访问 Slate Editor 实例，绕过所有 DOM 拦截，实现 100% 状态同步。
/// 不使用 Enter 键兜底（Android WebView 不支持），按钮 disabled 时直接报错而非强行解锁。
class ReactFiberStrategy extends InjectionStrategy {
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
    _log('[ReactFiber:$name] ====== STRATEGY START ====== msg.length=${message.length}');

    try {
      // Phase 0: 元素预检测（含重试）
      _log('[ReactFiber:$name] Phase0-Detect: checking input element...');
      final inputDetect = await waitForElement(
        controller: controller,
        xpath: inputXPath,
        name: name,
        label: 'input element',
      );
      if (inputDetect == null) {
        _log('[ReactFiber:$name] Phase0-Detect ABORT: input element NOT found after retries');
        return SubmissionResult(
          success: false,
          error: 'Input element not found',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      _log('[ReactFiber:$name] Phase0-Detect: input found, tag=${inputDetect['tag']}');

      // 额外检测 React Fiber 和 Slate
      final fiberDetectJs = '''
        $helpersJS
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
      final fiberResult = await controller.runJavaScriptReturningResult(fiberDetectJs);
      final fiberOk = safeParseJsonResult(fiberResult);
      _log('[ReactFiber:$name] Phase0-Detect: hasFiber=${fiberOk?['hasFiber']}, hasSlate=${fiberOk?['hasSlate']}');

      if (fiberOk?['hasFiber'] != true) {
        _log('[ReactFiber:$name] Phase0-Detect WARNING: no React Fiber on input element!');
      }
      if (fiberOk?['hasSlate'] != true) {
        _log('[ReactFiber:$name] Phase0-Detect WARNING: no Slate editor instance found!');
      }

      // Phase 1: 双重聚焦序列
      _log('[ReactFiber:$name] Phase1-Focus1: focusing editor...');
      final focus1Start = DateTime.now();
      final focus1Js = '''
        $helpersJS
        (function() {
          var editor = _findElement('${escapeJavaScript(inputXPath)}');
          if (!editor) return "not_found";
          editor.focus();
          _simulateClick(editor);
          return "ok";
        })()
      ''';
      final focus1Result = await controller.runJavaScriptReturningResult(focus1Js);
      final focus1Ms = DateTime.now().difference(focus1Start).inMilliseconds;
      _log('[ReactFiber:$name] Phase1-Focus1 result (${focus1Ms}ms): $focus1Result');
      await Future.delayed(const Duration(milliseconds: 200));

      _log('[ReactFiber:$name] Phase1-Focus2: second focus attempt...');
      final focus2Start = DateTime.now();
      final focus2Js = '''
        $helpersJS
        (function() {
          var editor = _findElement('${escapeJavaScript(inputXPath)}');
          if (!editor) return "not_found";
          editor.focus();
          _simulateClick(editor);
          return "ok";
        })()
      ''';
      final focus2Result = await controller.runJavaScriptReturningResult(focus2Js);
      final focus2Ms = DateTime.now().difference(focus2Start).inMilliseconds;
      _log('[ReactFiber:$name] Phase1-Focus2 result (${focus2Ms}ms): $focus2Result');
      await Future.delayed(const Duration(milliseconds: 100));

      // Phase 2: React Fiber 注入文本
      _log('[ReactFiber:$name] Phase2-FiberInject: injecting via Slate API...');
      final injectStart = DateTime.now();
      final injectJs = '''
        $helpersJS
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
      
      final injectResult = await controller.runJavaScriptReturningResult(injectJs);
      final injectOk = safeParseJsonResult(injectResult);
      final injectMs = DateTime.now().difference(injectStart).inMilliseconds;
      _log('[ReactFiber:$name] Phase2-FiberInject result (${injectMs}ms): $injectOk');

      if (injectOk == null || injectOk['success'] != true) {
        final error = (injectOk?['error'] as String?) ?? 'Fiber 注入失败';
        _log('[ReactFiber:$name] Phase2-FiberInject FAILED: $error');
        return SubmissionResult(
          success: false,
          error: error,
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      // Phase 3: 点击发送按钮（含重试验证）
      await Future.delayed(const Duration(milliseconds: 200));
      final clickResult = await submitWithRetry(
        controller: controller,
        inputXPath: inputXPath,
        submitXPath: submitXPath,
        fallbackSubmitXPath: 'button[aria-label="发送消息"]',
        clickFallbackSelector: 'button[aria-label="发送消息"]',
        clickJs: '''
          $helpersJS
          (function() {
            try {
              var btn = _findElement('${escapeJavaScript(submitXPath)}');
              if (!btn) return JSON.stringify({ success: false, error: '未找到发送按钮' });

              if (btn.disabled) {
                  return JSON.stringify({ success: false, error: '发送按钮被禁用，Fiber 注入可能未被 React 状态识别，请重试' });
              }

              _simulateSubmit(btn);
              return JSON.stringify({ success: true });
            } catch (e) {
              return JSON.stringify({ success: false, error: e.message });
            }
          })()
        ''',
        tabId: tabId,
        displayName: displayName,
      );

      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[ReactFiber:$name] ====== STRATEGY END (${totalMs}ms) ======');

      return clickResult;

    } catch (e, stack) {
      final totalMs = DateTime.now().difference(totalStart).inMilliseconds;
      _log('[ReactFiber:$name] EXCEPTION (${totalMs}ms): $e');
      _log('[ReactFiber:$name] Stack: $stack');
      return SubmissionResult(
        success: false,
        error: 'React Fiber 注入发生致命错误: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'ReactFiberStrategy', error: error);
  }
}
