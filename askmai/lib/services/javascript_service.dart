import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/exports.dart';
import 'injection/exports.dart';

/// JavaScript执行服务 - 处理JS注入和自动化
class JavascriptService {
  /// 执行表单提交操作 — 委托给具体的注入策略执行
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId, {
    String? strategyName,
  }) async {
    final strategy = StrategyFactory.getStrategy(strategyName);
    return strategy.executeSubmit(
      controller,
      inputXPath,
      submitXPath,
      message,
      tabId,
    );
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
  @override
  String toString() => 'JavascriptService()';
}
