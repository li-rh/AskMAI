import 'package:flutter/material.dart';

/// 全局焦点管理器 - 用于在菜单等操作后恢复输入框焦点
class InputFocusManager extends ChangeNotifier {
  FocusNode? _inputFocusNode;

  FocusNode? get inputFocusNode => _inputFocusNode;

  void setInputFocusNode(FocusNode focusNode) {
    _inputFocusNode = focusNode;
  }

  void restoreFocus() {
    _inputFocusNode?.requestFocus();
  }

  void removeFocus() {
    _inputFocusNode?.unfocus();
  }
}
