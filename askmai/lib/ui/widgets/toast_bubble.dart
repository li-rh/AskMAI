import 'dart:ui';
import 'package:flutter/material.dart';

/// 一个轻量级、淡入淡出的半透明气泡提示组件，自动适配深浅色模式与UI整体色调
/// 采用黑白灰无边框毛玻璃质感（Glassmorphism）与双层精致阴影设计，观感轻盈
class ToastBubble extends StatefulWidget {
  final String message;
  final Duration duration;

  const ToastBubble({
    Key? key,
    required this.message,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<ToastBubble> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // 在第一帧绘制后触发淡入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    // 在持续时间结束前200毫秒触发淡出
    final fadeOutDelay = widget.duration - const Duration(milliseconds: 200);
    Future.delayed(fadeOutDelay > Duration.zero ? fadeOutDelay : Duration.zero, () {
      if (mounted) {
        setState(() {
          _opacity = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 采用黑白灰轻盈质感色调，透明度设为66%配合毛玻璃
    final backgroundColor = isDark
        ? const Color(0xFF2A2A2A).withValues(alpha: 0.66) // 极简深灰，夜间模式更柔和
        : Colors.white.withValues(alpha: 0.66);          // 纯净白色，浅色模式更通透
        
    final textColor = isDark
        ? const Color(0xFFE2E2E2)  // 轻量浅灰白
        : const Color(0xFF2D2D2D);  // 质感深灰黑

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: Container(
          // 外层柔和阴影容器，无边框
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              // 主投影：纯中性色投影，边缘虚化更广，使气泡显得更轻盈
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -3,
              ),
              // 环境微光投影
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // 稍强模糊度以增强磨砂玻璃质感
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
