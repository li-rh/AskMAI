import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import 'injection_strategy.dart';

/// 通用的 React + Slate.js 注入策略 (原针对千问开发)
/// 利用 React Fiber 直接访问 Slate 实例，绕过所有 DOM 拦截，实现 100% 状态同步
class ReactFiberStrategy extends InjectionStrategy {
  @override
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId,
  ) async {
    try {
      // 1. 双重聚焦序列：对抗通义千问的首次失焦保护
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
      await controller.runJavaScriptReturningResult(focus1Js);
      await Future.delayed(const Duration(milliseconds: 200));

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
      await controller.runJavaScriptReturningResult(focus2Js);
      await Future.delayed(const Duration(milliseconds: 100));

      // 2. 利用 React Fiber 注入文本：直接调用 Slate API
      final injectJs = '''
        $helpersJS
        (function() {
          try {
            var editor = _findElement('${escapeJavaScript(inputXPath)}');
            if (!editor) return JSON.stringify({ success: false, error: '未找到编辑器' });

            // 获取 React Fiber 实例
            var fiberKey = Object.keys(editor).find(k => k.startsWith('__reactFiber'));
            if (!fiberKey) return JSON.stringify({ success: false, error: '未找到 React Fiber (请刷新页面)' });
            
            var fiber = editor[fiberKey];
            var slateEditor = null;
            
            // 向上回溯查找包含 editor 属性的 Fiber 节点
            while (fiber && !slateEditor) {
                if (fiber.memoizedProps && fiber.memoizedProps.editor) {
                    slateEditor = fiber.memoizedProps.editor;
                }
                fiber = fiber.return;
            }
            
            if (!slateEditor) {
                // 如果没找到 Slate 实例，但找到了元素，尝试检查是否是普通的 TEXTAREA 或 INPUT
                if (editor.tagName === 'TEXTAREA' || editor.tagName === 'INPUT') {
                    editor.value = '${escapeJavaScript(message)}';
                    editor.dispatchEvent(new Event('input', { bubbles: true }));
                    editor.dispatchEvent(new Event('change', { bubbles: true }));
                    return JSON.stringify({ success: true, method: 'standard_fallback' });
                }
                return JSON.stringify({ success: false, error: '未找到 Slate 内部实例且非标准输入框' });
            }

            // 使用 Slate API 操作内容
            try {
                // 1. 清空现有内容
                // 更加鲁棒的清空方式：全选并删除
                if (slateEditor.children && slateEditor.children.length > 0) {
                    try {
                        // 尝试选中全部内容
                        slateEditor.select({
                            anchor: slateEditor.start([]),
                            focus: slateEditor.end([])
                        });
                        slateEditor.deleteFragment();
                    } catch (selectError) {
                        // 如果 start([]) 失败，尝试传统的 [0, 0] 路径
                        try {
                            var lastPath = [slateEditor.children.length - 1];
                            var lastNode = slateEditor.children[slateEditor.children.length - 1];
                            // 递归找最后一个叶子节点
                            while(lastNode.children) {
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
            
            // 2. 插入新文本
            try {
                slateEditor.insertText('${escapeJavaScript(message)}');
            } catch (insertError) {
                // 最后的兜底：直接操作 DOM (虽然不推荐，但比失败好)
                editor.textContent = '${escapeJavaScript(message)}';
            }
            
            // 3. 触发必要的 DOM 事件同步（确保 React 合成事件捕捉到 input）
            editor.dispatchEvent(new InputEvent('input', { 
                bubbles: true, 
                cancelable: true,
                inputType: 'insertText',
                data: '${escapeJavaScript(message)}'
            }));

            return JSON.stringify({ success: true });
          } catch (e) {
            return JSON.stringify({ success: false, error: e.message });
          }
        })()
      ''';
      
      final injectResult = await controller.runJavaScriptReturningResult(injectJs);
      final injectOk = parseResult(injectResult);

      if (injectOk == null || injectOk['success'] != true) {
        return SubmissionResult(
          success: false,
          error: (injectOk?['error'] as String?) ?? 'Fiber 注入失败',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }

      // 3. 等待 React 完成异步渲染（按钮状态更新）并点击发送
      await Future.delayed(const Duration(milliseconds: 200));

      final submitJs = '''
        $helpersJS
        (function() {
          try {
            var btn = _findElement('${escapeJavaScript(submitXPath)}');
            // 如果 XPath 没找到，使用备用选择器
            if (!btn) btn = document.querySelector('button[aria-label="发送消息"]');
            
            if (!btn) return JSON.stringify({ success: false, error: '未找到发送按钮' });

            // 强行尝试激活按钮（作为兜底）
            if (btn.disabled) {
                btn.removeAttribute('disabled');
                btn.classList.remove('cursor-not-allowed');
            }
            
            _simulateClick(btn);
            return JSON.stringify({ success: true });
          } catch (e) {
            return JSON.stringify({ success: false, error: e.message });
          }
        })()
      ''';
      
      final submitResult = await controller.runJavaScriptReturningResult(submitJs);
      final submitOk = parseResult(submitResult);

      return SubmissionResult(
        success: submitOk?['success'] == true,
        error: submitOk?['error'] as String?,
        timestamp: DateTime.now(),
        tabId: tabId,
      );

    } catch (e) {
      return SubmissionResult(
        success: false,
        error: 'React Fiber 注入发生致命错误: $e',
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }
}
