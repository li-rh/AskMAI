import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/exports.dart';
import '../utils/json_utils.dart';
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
    String? displayName,
  }) async {
    final name = displayName ?? tabId;
    final startTime = DateTime.now();
    _log('[Stage5-JsService] START $name, strategy="$strategyName", inputXPath="$inputXPath", submitXPath="$submitXPath", msg.length=${message.length}');

    final strategy = StrategyFactory.getStrategy(strategyName);
    _log('[Stage5-JsService] Resolved strategy: ${strategy.runtimeType}');

    try {
      final result = await strategy.executeSubmit(
        controller,
        inputXPath,
        submitXPath,
        message,
        tabId,
        displayName: displayName,
      );

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      _log('[Stage5-JsService] DONE $name: ${result.getStatusString()} (${elapsed}ms)');
      return result;
    } catch (e, stack) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      _log('[Stage5-JsService] EXCEPTION $name: $e (${elapsed}ms)');
      _log('[Stage5-JsService] Stack: $stack');
      return SubmissionResult(
        success: false,
        error: 'JavascriptService error: $e',
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

  Future<void> installClipboardHook(WebViewController controller) async {
    const js = '''
      (function() {
        if (!window.__amaiCaptured) window.__amaiCaptured = '';
        if (!window.__amaiCaptureSeq) window.__amaiCaptureSeq = 0;
        if (!window.__amaiCopyHooked) {
          window.__amaiCopyHooked = true;
          document.addEventListener('copy', function(e) {
            try {
              var text = e.clipboardData.getData('text/plain');
              if (text) {
                window.__amaiCaptured = text;
                window.__amaiCaptureSeq++;
              }
            } catch(err) {}
          }, true);
        }
        if (navigator.clipboard && navigator.clipboard.writeText && !window.__amaiWriteTextHooked) {
          window.__amaiWriteTextHooked = true;
          Object.defineProperty(navigator.clipboard, 'writeText', {
            value: function(text) {
              window.__amaiCaptured = text;
              window.__amaiCaptureSeq++;
              return Promise.resolve();
            },
            writable: true,
            configurable: true
          });
        }
        if (navigator.clipboard && navigator.clipboard.write && !window.__amaiWriteHooked) {
          window.__amaiWriteHooked = true;
          Object.defineProperty(navigator.clipboard, 'write', {
            value: function(items) {
              try {
                items.forEach(function(item) {
                  if (item.types) item.types.forEach(function(t) {
                    if (t === 'text/plain') item.getType('text/plain').then(function(blob) {
                      var reader = new FileReader();
                      reader.onload = function() {
                        window.__amaiCaptured = reader.result;
                        window.__amaiCaptureSeq++;
                      };
                      reader.readAsText(blob);
                    });
                  });
                });
              } catch(e) {}
              return Promise.resolve();
            },
            writable: true,
            configurable: true
          });
        }
        if (!window.__amaiExecCmdHooked) {
          window.__amaiExecCmdHooked = true;
          var origExecCommand = document.execCommand.bind(document);
          document.execCommand = function(cmd) {
            if (cmd === 'copy') {
              try {
                var sel = window.getSelection();
                if (sel && sel.toString()) {
                  window.__amaiCaptured = sel.toString();
                  window.__amaiCaptureSeq++;
                }
              } catch(err) {}
              return true;
            }
            return origExecCommand.apply(document, arguments);
          };
        }
        if (!window.__amaiPromptHooked) {
          window.__amaiPromptHooked = true;
          window.__amaiOrigPrompt = window.prompt;
          window.prompt = function(msg, def) {
            if (def && typeof def === 'string' && def.length > 10) {
              window.__amaiCaptured = def;
              window.__amaiCaptureSeq++;
              return def;
            }
            if (msg && typeof msg === 'string' && /copy to clipboard|ctrl\\+c|ctrl\\+insert|复制|剪贴板/i.test(msg)) {
              return null;
            }
            return window.__amaiOrigPrompt ? window.__amaiOrigPrompt.call(window, msg, def) : null;
          };
        }
        if (!window.__amaiConfirmHooked) {
          window.__amaiConfirmHooked = true;
          window.__amaiOrigConfirm = window.confirm;
          window.confirm = function(msg) {
            if (typeof msg === 'string' && msg.length > 10) {
              window.__amaiCaptured = msg;
              window.__amaiCaptureSeq++;
              return true;
            }
            return window.__amaiOrigConfirm ? window.__amaiOrigConfirm.call(window, msg) : true;
          };
        }
        window.__amaiDebug = function() {
          return { hooked: true, capturedLen: window.__amaiCaptured.length, seq: window.__amaiCaptureSeq };
        };
      })();
    ''';
    try {
      await controller.runJavaScript(js);
    } catch (e) {
      debugPrint('[JavascriptService] installClipboardHook error: $e');
    }
  }

  Future<Map<String, dynamic>?> clickAndCapture(
    WebViewController controller,
    String xpath, {
    int timeoutMs = 1500,
  }) async {
    try {
      final initResult = await controller.runJavaScriptReturningResult('''
        (function() {
          var seqBefore = window.__amaiCaptureSeq || 0;
          var btn = document.evaluate(${jsonEncode(xpath)}, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
          if (!btn) return JSON.stringify({phase:'done',success:false,reason:'button_not_found'});
          btn.style.display = 'block';
          btn.style.pointerEvents = 'auto';
          btn.click();
          setTimeout(function() {
            btn.dispatchEvent(new MouseEvent('click', {bubbles:true,cancelable:true,view:window}));
          }, 500);
          window.__amaiCaptureStart = Date.now();
          window.__amaiCaptureSeqBefore = seqBefore;
          return JSON.stringify({phase:'polling'});
        })();
      ''');
      debugPrint('[JavascriptService] clickAndCapture init type=${initResult.runtimeType}, value=$initResult');
      final initParsed = _parseResult(initResult);
      if (initParsed != null && initParsed['phase'] == 'done') {
        debugPrint('[JavascriptService] clickAndCapture button not found');
        return initParsed;
      }
    } catch (e) {
      debugPrint('[JavascriptService] clickAndCapture init error: $e');
      return null;
    }

    final startTime = DateTime.now();
    final deadline = startTime.add(Duration(milliseconds: timeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        final pollResult = await controller.runJavaScriptReturningResult('''
          (function() {
            if ((window.__amaiCaptureSeq||0) > (window.__amaiCaptureSeqBefore||0) && window.__amaiCaptured) {
              return JSON.stringify({phase:'done',success:true,text:window.__amaiCaptured,elapsedMs:Date.now()-window.__amaiCaptureStart});
            }
            if (Date.now() - (window.__amaiCaptureStart||0) >= $timeoutMs) {
              return JSON.stringify({phase:'done',success:false,reason:'timeout',elapsedMs:Date.now()-(window.__amaiCaptureStart||0)});
            }
            return JSON.stringify({phase:'waiting'});
          })();
        ''');
        final parsed = _parseResult(pollResult);
        if (parsed != null && parsed['phase'] == 'done') {
          debugPrint('[JavascriptService] clickAndCapture result=$parsed');
          return parsed;
        }
      } catch (e) {
        debugPrint('[JavascriptService] clickAndCapture poll error: $e');
      }
    }
    debugPrint('[JavascriptService] clickAndCapture dart_timeout');
    return {'success': false, 'reason': 'dart_timeout'};
  }

  Future<String?> extractInnerText(
    WebViewController controller,
    String xpath,
  ) async {
    final js = '''
      (function() {
        try {
          var el = document.evaluate(${jsonEncode(xpath)}, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
          if (el) return el.innerText.trim();
          return null;
        } catch(e) {
          return null;
        }
      })();
    ''';
    try {
      final result = await controller.runJavaScriptReturningResult(js);
      debugPrint('[JavascriptService] extractInnerText rawResult type=${result.runtimeType}, value=$result');
      var text = result is String ? result : result.toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        try {
          text = jsonDecode(text);
        } catch (_) {}
      }
      debugPrint('[JavascriptService] extractInnerText decoded text: ${text.isEmpty ? "EMPTY" : "len=${text.length}"}');
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('[JavascriptService] extractInnerText error: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseResult(dynamic rawResult) {
    return safeParseJsonResult(rawResult);
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'JavascriptService', error: error);
  }

  @override
  String toString() => 'JavascriptService()';
}
