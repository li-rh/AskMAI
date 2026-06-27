import 'dart:async';
import 'package:flutter/material.dart';
import '../ui/widgets/toast_bubble.dart';

/// 在屏幕顶部显示提示弹窗
/// 使用 OverlayEntry 实现，确保所有提示都显示在顶部
class TopToast {
  static OverlayEntry? _currentOverlayEntry;
  static Timer? _timer;

  /// 在屏幕顶部显示提示信息
  /// [backgroundColor] 可选的背景颜色，默认使用 ToastBubble 的主题色
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1500),
    Color? backgroundColor,
  }) {
    // 取消之前的提示
    _timer?.cancel();
    if (_currentOverlayEntry != null) {
      _currentOverlayEntry!.remove();
      _currentOverlayEntry = null;
    }

    _currentOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.center,
          child: ToastBubble(
            message: message,
            duration: duration,
            backgroundColor: backgroundColor,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlayEntry!);

    _timer = Timer(duration, () {
      if (_currentOverlayEntry != null) {
        _currentOverlayEntry!.remove();
        _currentOverlayEntry = null;
      }
    });
  }
}
