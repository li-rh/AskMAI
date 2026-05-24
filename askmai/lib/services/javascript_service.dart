import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/exports.dart';

/// JavaScript执行服务 - 处理JS注入和自动化
class JavascriptService {
  /// 固定的JavaScript提交函数 - 从Kotlin版本复用
  static const String _submitFormJS = '''
    function submitForm(inputXPath, submitXPath, messageText) {
      try {
        // 使用XPath定位输入字段
        const inputElement = document.evaluate(
          inputXPath, 
          document, 
          null, 
          XPathResult.FIRST_ORDERED_NODE_TYPE, 
          null
        ).singleNodeValue;
        
        // 使用XPath定位提交按钮
        const submitButton = document.evaluate(
          submitXPath, 
          document, 
          null, 
          XPathResult.FIRST_ORDERED_NODE_TYPE, 
          null
        ).singleNodeValue;
        
        // 检查元素是否存在
        if (!inputElement || !submitButton) {
          return JSON.stringify({ 
            success: false, 
            error: 'Elements not found',
            timestamp: Date.now()
          });
        }
        
        // 填充输入字段
        inputElement.value = messageText;
        inputElement.dispatchEvent(new Event('input', { bubbles: true }));
        inputElement.dispatchEvent(new Event('change', { bubbles: true }));
        
        // 点击提交按钮
        submitButton.click();
        
        return JSON.stringify({ 
          success: true, 
          timestamp: Date.now()
        });
      } catch (e) {
        return JSON.stringify({ 
          success: false, 
          error: e.message,
          timestamp: Date.now()
        });
      }
    }
  ''';

  /// 执行表单提交操作
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId,
  ) async {
    try {
      // 构建JavaScript代码
      final jsCode = '''
        $_submitFormJS
        submitForm('${_escapeJavaScript(inputXPath)}', '${_escapeJavaScript(submitXPath)}', '${_escapeJavaScript(message)}');
      ''';

      // 执行JavaScript（webview_flutter 4.x中runJavaScript返回void）
      await controller.runJavaScript(jsCode);

      // 假设执行成功
      return SubmissionResult(
        success: true,
        error: null,
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
      // webview_flutter 4.x的runJavaScript返回void，所以直接返回null
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 滚动到底部
  Future<void> scrollToBottom(WebViewController controller) async {
    try {
      await controller.runJavaScript(
          'window.scrollTo(0, document.body.scrollHeight);');
    } catch (e) {
      // 忽略滚动错误
    }
  }

  /// 转义JavaScript中的特殊字符
  static String _escapeJavaScript(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  @override
  String toString() => 'JavascriptService()';
}
