import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';
import 'aggregate_dialog.dart';

/// 输入框区域 - 用户输入和发送按钮
class InputArea extends StatefulWidget {
  final VoidCallback onNewChat;
  final VoidCallback onSettings;
  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;
  final VoidCallback? onHorizontalDragCancel;

  const InputArea({
    Key? key,
    required this.onNewChat,
    required this.onSettings,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final isFocused = context.watch<InputFocusManager>().hasFocus;

    return Consumer3<InputDistributorVM, TabManagerVM, AggregationVM>(
      builder: (context, distributorVM, tabManagerVM, aggVM, _) {
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
        final showAggregate = Platform.isAndroid || Platform.isIOS;

        return Container(
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 8,
              right: 16,
              top: 4,
              bottom: 8,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 输入框
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: colorScheme.surface,
                            border: Border.all(
                              color: theme.brightness == Brightness.light
                                  ? Colors.black.withValues(alpha: 0.06)
                                  : Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.brightness == Brightness.light
                                    ? Colors.black.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
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
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        if (!isFocused)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _focusNode.requestFocus();
                              },
                              onHorizontalDragStart: widget.onHorizontalDragStart,
                              onHorizontalDragUpdate: widget.onHorizontalDragUpdate,
                              onHorizontalDragEnd: widget.onHorizontalDragEnd,
                              onHorizontalDragCancel: widget.onHorizontalDragCancel,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 右侧按钮列（聚合发送 + 发送按钮）
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showAggregate)
                        SizedBox(
                          height: 30,
                          width: 30,
                          child: Material(
                            color: Colors.transparent,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: enabledTabs.isEmpty || aggVM.isAggregating
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
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: enabledTabs.isEmpty || aggVM.isAggregating
                                        ? null
                                        : () => showAggregateDialog(context),
                                    borderRadius: BorderRadius.circular(15),
                                    child: Center(
                                      child: aggVM.isAggregating
                                          ? SizedBox(
                                              width: 15,
                                              height: 15,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                        colorScheme.onPrimary),
                                              ),
                                            )
                                          : Icon(
                                              Icons.merge_type_rounded,
                                              color: colorScheme.onPrimary,
                                              size: 14,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showAggregate) const SizedBox(height: 4),
                      // 发送按钮
                      SizedBox(
                        height: 40,
                        width: 40,
                        child: Material(
                          color: Colors.transparent,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
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
                                  borderRadius: BorderRadius.circular(20),
                                  child: Center(
                                    child: distributorVM.isSubmitting
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      colorScheme.onPrimary),
                                            ),
                                          )
                                        : Icon(
                                            Icons.send_rounded,
                                            color: colorScheme.onPrimary,
                                            size: 18,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}