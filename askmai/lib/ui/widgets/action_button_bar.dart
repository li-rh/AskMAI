import 'package:flutter/material.dart';

/// 功能按钮栏 - 显示新建对话、设置等按钮，可左右滑动
class ActionButtonBar extends StatelessWidget {
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  const ActionButtonBar({
    Key? key,
    required this.onNewChat,
    required this.onSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 新建对话按钮
            _ActionButton(
              icon: Icons.chat_bubble,
              label: '新建对话',
              onPressed: onNewChat,
              theme: theme,
              showPlusIcon: true,
            ),
            const SizedBox(width: 8),
            // 设置按钮
            _ActionButton(
              icon: Icons.settings,
              label: '设置',
              onPressed: onSettings,
              theme: theme,
            ),
            // 预留位置供未来扩展
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// 单个功能按钮
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ThemeData theme;
  final bool showPlusIcon;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.showPlusIcon = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePressed() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handlePressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Icon(
                      widget.icon,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    if (widget.showPlusIcon)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: widget.theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
