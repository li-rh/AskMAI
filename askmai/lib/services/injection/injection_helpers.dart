import 'package:webview_flutter/webview_flutter.dart';
import '../../models/exports.dart';
import '../../utils/json_utils.dart';

/// 共用的 DOM 查询与点击工具函数（注入到 WebView 执行的 JavaScript）
const String helpersJS = '''
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
    if (!el) return;
    var r = el.getBoundingClientRect();
    var cx = r.left + r.width / 2;
    var cy = r.top + r.height / 2;
    var o = { bubbles: true, cancelable: true, clientX: cx, clientY: cy };
    
    if (window.TouchEvent) {
      try {
        var touch = new Touch({
          identifier: Date.now(),
          target: el,
          clientX: cx,
          clientY: cy,
          screenX: cx,
          screenY: cy,
          pageX: cx,
          pageY: cy
        });
        var touchOpts = { 
          bubbles: true, 
          cancelable: true, 
          touches: [touch], 
          targetTouches: [touch], 
          changedTouches: [touch] 
        };
        el.dispatchEvent(new TouchEvent('touchstart', touchOpts));
        el.dispatchEvent(new TouchEvent('touchend', touchOpts));
      } catch (e) {
        el.dispatchEvent(new Event('touchstart', o));
        el.dispatchEvent(new Event('touchend', o));
      }
    } else {
      el.dispatchEvent(new Event('touchstart', o));
      el.dispatchEvent(new Event('touchend', o));
    }
    
    el.dispatchEvent(new PointerEvent('pointerdown', o));
    el.dispatchEvent(new MouseEvent('mousedown', o));
    el.dispatchEvent(new PointerEvent('pointerup', o));
    el.dispatchEvent(new MouseEvent('mouseup', o));
    el.dispatchEvent(new MouseEvent('click', o));
  }
  function _simulateSubmit(el) {
    if (!el) return;
    _simulateClick(el);
    try {
      if (el.__vue__ || el._vnode) {
        if (el.__vue__ && el.__vue__.\$emit) {
          el.__vue__.\$emit('click');
        }
        if (el._vnode && el._vnode.props && el._vnode.props.onClick) {
          el._vnode.props.onClick();
        }
      }
    } catch (e) {
      console.warn('Vue bypass event failed:', e);
    }
  }
  function _findSubmitButton(primarySelector, fallbackSelector) {
    var btn = _findElement(primarySelector);
    if (!btn && fallbackSelector) btn = document.querySelector(fallbackSelector);
    return btn;
  }
  function _isDisabled(el) {
    if (el.disabled === true) return true;
    if (el.getAttribute('aria-disabled') === 'true') return true;
    if (el.classList.contains('disabled')) return true;
    return false;
  }
''';

/// 转义 JavaScript 中的特殊字符
String escapeJavaScript(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
}

/// 等待元素出现在页面上，最多重试 [maxRetries] 次，每次间隔 [intervalMs] 毫秒
Future<Map<String, dynamic>?> waitForElementShared({
  required WebViewController controller,
  required String xpath,
  required String name,
  String label = 'element',
  int maxRetries = 5,
  int intervalMs = 500,
  required void Function(String) log,
}) async {
  final detectJs = '''
    $helpersJS
    (function() {
      var el = _findElement('${escapeJavaScript(xpath)}');
      if (!el) return JSON.stringify({ found: false });
      return JSON.stringify({ found: true, tag: el.tagName, editable: el.isContentEditable || el.contentEditable === 'true' });
    })()
  ''';
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    final result = await controller.runJavaScriptReturningResult(detectJs);
    final parsed = safeParseJsonResult(result);

    if (parsed != null && parsed['found'] == true) {
      if (attempt > 1) {
        log('[$name] $label found on attempt $attempt');
      }
      return parsed;
    }

    if (attempt < maxRetries) {
      log('[$name] $label not found, retry $attempt/$maxRetries: waiting ${intervalMs}ms...');
      await Future.delayed(Duration(milliseconds: intervalMs));
    }
  }

  log('[$name] $label NOT found after $maxRetries retries');
  return null;
}

/// 统一的发送按钮提交流程：预检测 → 点击 → 重试验证
Future<SubmissionResult> submitWithRetryShared({
  required WebViewController controller,
  required String inputXPath,
  required String submitXPath,
  required String clickJs,
  required String tabId,
  String? displayName,
  String? fallbackSubmitXPath,
  String? clickFallbackSelector,
  int maxRetries = 5,
  required void Function(String) log,
}) async {
  final name = displayName ?? tabId;

  final preCheckJs = '''
    $helpersJS
    (function() {
      var btn = _findElement('${escapeJavaScript(submitXPath)}');
      ${fallbackSubmitXPath != null ? "if (!btn) btn = document.querySelector('${escapeJavaScript(fallbackSubmitXPath)}');" : ''}
      return JSON.stringify({
        found: !!btn,
        tag: btn ? btn.tagName : null,
        disabled: btn ? _isDisabled(btn) : null
      });
    })()
  ''';
  var buttonReady = false;
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    final preCheckResult = await controller.runJavaScriptReturningResult(preCheckJs);
    final preCheckOk = safeParseJsonResult(preCheckResult);
    log('[$name] Submit pre-check attempt $attempt: found=${preCheckOk?['found']}, tag=${preCheckOk?['tag']}, disabled=${preCheckOk?['disabled']}');

    if (preCheckOk?['found'] == true && preCheckOk?['disabled'] != true) {
      log('[$name] Submit button is ready');
      buttonReady = true;
      break;
    }

    if (attempt < maxRetries) {
      final reason = preCheckOk?['found'] != true ? 'not found' : 'disabled';
      log('[$name] Submit $reason, retry $attempt/$maxRetries: waiting 1000ms...');
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }
  if (!buttonReady) {
    log('[$name] Submit ABORT: button not ready after $maxRetries retries');
    return SubmissionResult(
      success: false,
      error: 'Submit button not ready after $maxRetries retries',
      timestamp: DateTime.now(),
      tabId: tabId,
    );
  }

  final verifyJs = '''
    $helpersJS
    (function() {
      var el = _findElement('${escapeJavaScript(inputXPath)}');
      if (!el) return JSON.stringify({ hasContent: false, found: false });
      var hasContent = (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT')
        ? el.value.length > 0
        : el.textContent.trim().length > 0;
      return JSON.stringify({ hasContent: hasContent, found: true });
    })()
  ''';
  final resolvedClickJs = clickFallbackSelector != null
      ? clickJs.replaceAll(
          "_findElement('${escapeJavaScript(submitXPath)}')",
          "_findSubmitButton('${escapeJavaScript(submitXPath)}', '${escapeJavaScript(clickFallbackSelector)}')",
        )
      : clickJs;

  var clickOk = <String, dynamic>{'success': false};
  var hasClicked = false;
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    final clickStart = DateTime.now();
    final clickResult = await controller.runJavaScriptReturningResult(resolvedClickJs);
    final currentResult = safeParseJsonResult(clickResult) ?? clickOk;
    final clickMs = DateTime.now().difference(clickStart).inMilliseconds;
    log('[$name] Submit click attempt $attempt (${clickMs}ms): $currentResult');

    if (currentResult['success'] == true) {
      hasClicked = true;
      clickOk = currentResult;
    }

    await Future.delayed(const Duration(milliseconds: 1000));

    final verifyResult = await controller.runJavaScriptReturningResult(verifyJs);
    final verifyOk = safeParseJsonResult(verifyResult);

    if (verifyOk == null || verifyOk['hasContent'] != true) {
      log('[$name] Submit verify: input is empty, click succeeded');
      if (!hasClicked) {
        clickOk = {'success': true, 'error': null, 'step': 'verify'};
      }
      break;
    }

    if (hasClicked && currentResult['error']?.toString().contains('disabled') == true) {
      log('[$name] Submit button disabled after successful click, likely sending');
      clickOk = {'success': true, 'error': null, 'step': 'disabled_after_click'};
      break;
    }

    log('[$name] Submit retry $attempt/$maxRetries: input still has content');
  }

  return SubmissionResult(
    success: clickOk['success'] == true,
    error: clickOk['error'] as String?,
    timestamp: DateTime.now(),
    tabId: tabId,
  );
}

/// 注入回答状态监听脚本（共享的 DOM 观察器）
Future<void> injectAnswerStatusObserverShared({
  required WebViewController controller,
  required String? answerContentXPath,
  required String name,
  required void Function(String) log,
}) async {
  final answerXPath = answerContentXPath ?? '';
  final js = '''
    (function() {
      if (window.AskMAIAnswerObserver) {
        try { window.AskMAIAnswerObserver.disconnect(); } catch(e) {}
      }
      if (window.AskMAIAnswerCheckInterval) {
        try { clearInterval(window.AskMAIAnswerCheckInterval); } catch(e) {}
      }
      if (window.AskMAIAnswerTimer) {
        try { clearTimeout(window.AskMAIAnswerTimer); } catch(e) {}
        window.AskMAIAnswerTimer = null;
      }
      if (window.AskMAIAnswerSafetyTimer) {
        try { clearTimeout(window.AskMAIAnswerSafetyTimer); } catch(e) {}
        window.AskMAIAnswerSafetyTimer = null;
      }
      
      var answerXPath = '${escapeJavaScript(answerXPath)}';
      if (answerXPath === 'TODO_FILL_ME') answerXPath = ''; // Filter out placeholder
      
      var lastAnswerText = '';
      var lastChangeTime = Date.now();
      var active = false;
      var checkInterval = null;
      
      function post(status) {
        try {
          if (window.AskMAIDomChangeChannel) {
            window.AskMAIDomChangeChannel.postMessage(status);
          } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AskMAIDomChangeChannel) {
            window.webkit.messageHandlers.AskMAIDomChangeChannel.postMessage(status);
          } else if (typeof AskMAIDomChangeChannel !== 'undefined') {
            AskMAIDomChangeChannel.postMessage(status);
          }
        } catch(e) {}
      }
      
      function getAnswerText() {
        if (!answerXPath) return '';
        try {
          var el = document.evaluate(answerXPath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
          return el ? (el.innerText || el.textContent || '') : '';
        } catch(e) {
          return '';
        }
      }

      function isGeneratingOrThinking() {
        var stopButtons = document.querySelectorAll('button, [role="button"]');
        for (var i = 0; i < stopButtons.length; i++) {
          var btn = stopButtons[i];
          var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || btn.innerText || '').toLowerCase();
          if (label.indexOf('stop') !== -1 || label.indexOf('停止') !== -1 || label.indexOf('中断') !== -1 || label.indexOf('cancel') !== -1) {
            if (btn.offsetWidth > 0 && btn.offsetHeight > 0 && !btn.disabled) return true;
          }
        }
        var docText = document.body ? document.body.innerText : '';
        if (docText.indexOf('正在思考') !== -1 || 
            docText.indexOf('正在搜索') !== -1 || 
            docText.indexOf('正在联网') !== -1 || 
            docText.indexOf('Thinking...') !== -1 || 
            docText.indexOf('Searching...') !== -1) {
          return true;
        }
        var selectors = [
          '.ds-markdown--thought', '.thought-block', '.thinking', '.searching', 
          '[data-testid="search-status"]', '.search-pill', '.result-streaming', 
          '.streaming', '.typing-indicator', '.loading-indicator'
        ];
        for (var j = 0; j < selectors.length; j++) {
          var el = document.querySelector(selectors[j]);
          if (el && el.offsetWidth > 0 && el.offsetHeight > 0) return true;
        }
        var cursors = document.querySelectorAll('.cursor, .blink, .pulse');
        for (var k = 0; k < cursors.length; k++) {
          var cursor = cursors[k];
          if (cursor.offsetWidth > 0 && cursor.offsetHeight > 0 && cursor.tagName !== 'INPUT' && cursor.tagName !== 'TEXTAREA') {
            return true;
          }
        }
        return false;
      }
      
      function disconnectObserver() {
        if (observer) observer.disconnect();
        if (checkInterval) clearInterval(checkInterval);
        if (window.AskMAIAnswerTimer) {
          clearTimeout(window.AskMAIAnswerTimer);
          window.AskMAIAnswerTimer = null;
        }
        if (window.AskMAIAnswerSafetyTimer) {
          clearTimeout(window.AskMAIAnswerSafetyTimer);
          window.AskMAIAnswerSafetyTimer = null;
        }
      }

      function updateState() {
        var generating = isGeneratingOrThinking();
        var currentText = getAnswerText();
        var hasContentChanged = (currentText !== lastAnswerText);
        
        if (hasContentChanged) {
          lastAnswerText = currentText;
          lastChangeTime = Date.now();
        }
        
        if (generating || (hasContentChanged && currentText.trim().length > 0)) {
          if (!active) {
            active = true;
            post("active");
          }
          if (window.AskMAIAnswerTimer) {
            clearTimeout(window.AskMAIAnswerTimer);
            window.AskMAIAnswerTimer = null;
          }
        } else {
          if (active && !window.AskMAIAnswerTimer) {
            var elapsedSinceChange = Date.now() - lastChangeTime;
            var timeoutDelay = Math.max(0, 3000 - elapsedSinceChange);
            window.AskMAIAnswerTimer = setTimeout(function() {
              var currentGenerating = isGeneratingOrThinking();
              var currentText2 = getAnswerText();
              if (!currentGenerating && currentText2 === lastAnswerText) {
                active = false;
                post("idle");
                disconnectObserver();
              }
              window.AskMAIAnswerTimer = null;
            }, timeoutDelay);
          }
        }
      }

      var observer = new MutationObserver(updateState);
      observer.observe(document.body || document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        characterData: true
      });
      
      checkInterval = setInterval(updateState, 500);
      
      window.AskMAIAnswerObserver = observer;
      window.AskMAIAnswerCheckInterval = checkInterval;

      // Overall safety timeout (120s max lifetime)
      window.AskMAIAnswerSafetyTimer = setTimeout(function() {
        post("idle");
        disconnectObserver();
      }, 120000);
    })();
  ''';
  try {
    await controller.runJavaScript(js);
    log('Answer status observer injected successfully');
  } catch (e) {
    log('Error injecting answer status observer: $e');
  }
}
