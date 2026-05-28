import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';
import 'viewport_adjust_dialog.dart';

/// 输入框区域 - 用户输入和发送按钮
class InputArea extends StatefulWidget {
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  const InputArea({Key? key, required this.onNewChat, required this.onSettings})
    : super(key: key);

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    // 注册焦点节点到全局InputFocusManager
    Future.microtask(() {
      if (mounted) {
        context.read<InputFocusManager>().setInputFocusNode(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend(
    InputDistributorVM distributorVM,
    TabManagerVM tabManagerVM,
  ) async {
    final message = _controller.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 检查是否有显示和启用的tab
    final enabledTabs = tabManagerVM.tabs
        .where((tab) => tab.isDisplayed && tab.isEnabled)
        .toList();

    if (enabledTabs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable at least one tab'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _controller.clear();
    _focusNode.unfocus();

    await distributorVM.broadcastInput(message);

    // 显示成功消息
    if (mounted) {
      final successCount = distributorVM.getSuccessCount();
      final failureCount = distributorVM.getFailureCount();

      if (successCount > 0 && failureCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to $successCount tab(s)'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else if (failureCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount sent, $failureCount failed'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showViewportAdjustDialog(TabManagerVM tabManagerVM) {
    final activeTabId = tabManagerVM.activeTabId;
    if (activeTabId == null) return;
    // 获取原始的 tab，而不是可能包含预览状态的 tab
    final activeTab = tabManagerVM.getTab(activeTabId);
    if (activeTab == null) return;
    showDialog(
      context: context,
      builder: (_) => ViewportAdjustDialog(
        tab: activeTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<InputDistributorVM, TabManagerVM>(
      builder: (context, distributorVM, tabManagerVM, _) {
        // 计算显示的和启用的tab数量
        final displayedTabs = tabManagerVM.tabs
            .where((tab) => tab.isDisplayed)
            .toList();
        final enabledTabs = displayedTabs
            .where((tab) => tab.isEnabled)
            .toList();

        final isDisabled = distributorVM.isSubmitting || enabledTabs.isEmpty;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 4,
              bottom: 16,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧"新建对话"和"设置"按钮，上下布局，与输入框等高
                  SizedBox(
                    width: 44,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _CompactIconButton(
                            icon: Icons.add_comment_rounded,
                            onPressed: widget.onNewChat,
                            theme: theme,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _CompactIconButton(
                            icon: Icons.settings_rounded,
                            onPressed: widget.onSettings,
                            theme: theme,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 中间输入框
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !isDisabled,
                        maxLines: 5,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: enabledTabs.isEmpty
                              ? 'Enable a tab first...'
                              : 'Ask ${enabledTabs.length} LLM${enabledTabs.length != 1 ? 's' : ''}...',
                          hintStyle: TextStyle(
                            color:
                                theme.textTheme.bodySmall?.color ??
                                Colors.grey[400],
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.dividerColor,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.dividerColor,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.dividerColor,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 右侧操作按钮列：视图调整按钮在上，发送按钮在下
                  SizedBox(
                    width: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 视图调整按钮
                        Align(
                          alignment: Alignment.topCenter,
                          child: _ViewportButton(
                            tabManagerVM: tabManagerVM,
                            theme: theme,
                          ),
                        ),
                        const Spacer(),
                        // 发送按钮
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: isDisabled
                                      ? LinearGradient(
                                          colors: [
                                            colorScheme.onSurface.withValues(
                                              alpha: 0.2,
                                            ),
                                            colorScheme.onSurface.withValues(
                                              alpha: 0.3,
                                            ),
                                          ],
                                        )
                                      : LinearGradient(
                                          colors: [
                                            colorScheme.primary,
                                            colorScheme.primary.withValues(
                                              alpha: 0.8,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isDisabled
                                                  ? colorScheme.onSurface
                                                  : colorScheme.primary)
                                              .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: isDisabled
                                        ? null
                                        : () => _handleSend(
                                            distributorVM,
                                            tabManagerVM,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Center(
                                      child: distributorVM.isSubmitting
                                          ? SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(colorScheme.onPrimary),
                                              ),
                                            )
                                          : Icon(
                                              Icons.send_rounded,
                                              color: colorScheme.onPrimary,
                                              size: 22,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 紧凑的图标按钮，仅显示图标
class _CompactIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final ThemeData theme;
  final double? width;
  final double? height;

  const _CompactIconButton({
    required this.icon,
    required this.onPressed,
    required this.theme,
    this.width,
    this.height,
  });

  @override
  State<_CompactIconButton> createState() => _CompactIconButtonState();
}

class _CompactIconButtonState extends State<_CompactIconButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
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
            height: widget.height ?? 36,
            width: widget.width ?? 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(widget.icon, color: colorScheme.primary, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// 紧凑的视图调整按钮 - 点击弹出视图调整对话框
class _ViewportButton extends StatelessWidget {
  final TabManagerVM tabManagerVM;
  final ThemeData theme;

  const _ViewportButton({required this.tabManagerVM, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final activeTab = tabManagerVM.activeTab;
    final isViewportEnabled =
        activeTab != null &&
        !activeTab.viewportDisabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final state = context.findAncestorStateOfType<_InputAreaState>();
          state?._showViewportAdjustDialog(tabManagerVM);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isViewportEnabled
                ? colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border.all(
              color: isViewportEnabled
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.view_quilt_rounded,
              color: isViewportEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.4),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
