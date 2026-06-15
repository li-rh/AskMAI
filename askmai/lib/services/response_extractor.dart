import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/exports.dart';
import 'javascript_service.dart';

class ResponseExtractor {
  static const _placeholderPrefix = 'TODO_';
  static const _minTextLength = 2;  // 设置一个合理的最小长度，过滤掉无效的提取结果
  static const _extractionTimeout = Duration(seconds: 2);

  final JavascriptService _jsService;

  ResponseExtractor(this._jsService);

  Future<String?> extract({
    required WebViewController controller,
    required SiteConfig siteConfig,
  }) async {
    debugPrint('[ResponseExtractor] extract start for ${siteConfig.id}');
    if (_isValidXPath(siteConfig.copyButtonXPath)) {
      debugPrint('[ResponseExtractor] trying clickAndCapture with xpath=${siteConfig.copyButtonXPath}');
      try {
        final result = await _jsService
            .clickAndCapture(controller, siteConfig.copyButtonXPath!)
            .timeout(_extractionTimeout);
        debugPrint('[ResponseExtractor] clickAndCapture result=$result');
        if (result != null && result['success'] == true) {
          final text = result['text'] as String?;
          if (text != null && text.trim().length >= _minTextLength) {
            return text.trim();
          }
          debugPrint('[ResponseExtractor] clickAndCapture success but text too short: len=${text?.trim().length}');
        }
        _log('Clipboard intercept failed for ${siteConfig.id}, falling back');
        debugPrint('[ResponseExtractor] Clipboard intercept failed for ${siteConfig.id}, falling back. result=$result');
      } catch (e) {
        _log('Clipboard intercept error for ${siteConfig.id}: $e');
        debugPrint('[ResponseExtractor] Clipboard intercept error for ${siteConfig.id}: $e');
      }
    } else {
      final reason = siteConfig.copyButtonXPath == null
          ? 'null'
          : siteConfig.copyButtonXPath!.isEmpty
              ? 'empty'
              : 'placeholder';
      debugPrint('[ResponseExtractor] copyButtonXPath skipped ($reason) for ${siteConfig.id}');
    }

    if (_isValidXPath(siteConfig.responseXPath)) {
      debugPrint('[ResponseExtractor] trying extractInnerText with xpath=${siteConfig.responseXPath}');
      try {
        final text = await _jsService
            .extractInnerText(controller, siteConfig.responseXPath!)
            .timeout(_extractionTimeout);
        debugPrint('[ResponseExtractor] extractInnerText result: ${text != null ? "len=${text.length} prefix=${text.substring(0, text.length > 50 ? 50 : text.length)}" : "NULL"}');
        if (text != null && text.trim().length >= _minTextLength) {
          return text.trim();
        }
        debugPrint('[ResponseExtractor] extractInnerText text too short or null: len=${text?.trim().length}');
      } catch (e) {
        _log('InnerText extraction error for ${siteConfig.id}: $e');
        debugPrint('[ResponseExtractor] InnerText extraction error for ${siteConfig.id}: $e');
      }
    } else {
      final reason = siteConfig.responseXPath == null
          ? 'null'
          : siteConfig.responseXPath!.isEmpty
              ? 'empty'
              : 'placeholder';
      debugPrint('[ResponseExtractor] responseXPath skipped ($reason) for ${siteConfig.id}');
    }

    debugPrint('[ResponseExtractor] ALL extraction failed for ${siteConfig.id}, returning null');
    return null;
  }

  bool _isValidXPath(String? xpath) {
    if (xpath == null || xpath.isEmpty) return false;
    if (xpath.startsWith(_placeholderPrefix)) return false;
    return true;
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'ResponseExtractor', error: error);
  }
}
