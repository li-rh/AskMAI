import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web端软键盘弹出检测管理器
/// 使用 visualViewport API 检测键盘状态
class KeyboardVisibilityManager extends ChangeNotifier {
  bool _isVisible = false;

  bool get isVisible => _isVisible;

  KeyboardVisibilityManager() {
    _check();
    final viewport = html.window.visualViewport;
    viewport?.onResize?.listen((_) => _check());
    html.window.onResize.listen((_) => _check());
  }

  void _check() {
    final viewport = html.window.visualViewport;
    if (viewport == null) {
      return;
    }
    final heightDiff = html.window.innerHeight! - viewport.height!;
    final visible = heightDiff > 100;
    if (visible != _isVisible) {
      _isVisible = visible;
      notifyListeners();
    }
  }
}