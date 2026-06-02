import 'package:flutter/material.dart';

/// 移动端软键盘弹出检测管理器
/// 使用 WidgetsBindingObserver 监听 viewInsets 变化
class KeyboardVisibilityManager extends ChangeNotifier
    with WidgetsBindingObserver {
  bool _isVisible = false;

  bool get isVisible => _isVisible;

  KeyboardVisibilityManager() {
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void didChangeMetrics() {
    _check();
  }

  void _check() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final bottom = view.viewInsets.bottom / view.devicePixelRatio;
    final visible = bottom > 100;
    if (visible != _isVisible) {
      _isVisible = visible;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}