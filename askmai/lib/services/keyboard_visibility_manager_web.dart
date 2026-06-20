// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Web端软键盘弹出检测管理器
/// 使用 visualViewport API 检测键盘状态
class KeyboardVisibilityManager extends ChangeNotifier {
  bool _isVisible = false;
  FocusNode? _inputFocusNode;

  bool get isVisible => _isVisible;

  KeyboardVisibilityManager() {
    _check();
    final viewport = html.window.visualViewport;
    viewport?.onResize.listen((_) => _check());
    html.window.onResize.listen((_) => _check());
  }

  void setInputFocusNode(FocusNode focusNode) {
    _inputFocusNode = focusNode;
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

      if (!visible && _inputFocusNode?.hasFocus == true) {
        _inputFocusNode?.unfocus();
      }

      notifyListeners();
    }
  }
}