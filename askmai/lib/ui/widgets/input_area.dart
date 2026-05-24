import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/exports.dart';

/// 输入框区域 - 用户输入和发送按钮
class InputArea extends StatefulWidget {
  const InputArea({Key? key}) : super(key: key);

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend(InputDistributorVM distributorVM,
      TabManagerVM tabManagerVM) async {
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

    if (tabManagerVM.tabs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one tab'),
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
    return Consumer2<InputDistributorVM, TabManagerVM>(
      builder: (context, distributorVM, tabManagerVM, _) {
        final isDisabled = distributorVM.isSubmitting ||
            tabManagerVM.tabs.isEmpty;

        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            color: Colors.white,
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !isDisabled,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!isDisabled) {
                          _handleSend(distributorVM, tabManagerVM);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: tabManagerVM.tabs.isEmpty
                            ? 'Add a tab first...'
                            : 'Ask all ${tabManagerVM.tabs.length} LLMs...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.blue,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: FloatingActionButton(
                      onPressed: isDisabled
                          ? null
                          : () => _handleSend(distributorVM, tabManagerVM),
                      backgroundColor: isDisabled ? Colors.grey : Colors.blue,
                      disabledElevation: 0,
                      elevation: 2,
                      child: distributorVM.isSubmitting
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: isDisabled ? Colors.grey[600] : Colors.white,
                            ),
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
