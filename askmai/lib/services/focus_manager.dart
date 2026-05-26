import 'package:flutter/material.dart';

/// 全局焦点管理器 - 用于在菜单等操作后恢复输入框焦点
class InputFocusManager extends ChangeNotifier {
  FocusNode? _inputFocusNode;

  FocusNode? get inputFocusNode => _inputFocusNode;
  bool get hasFocus => _inputFocusNode?.hasFocus ?? false;

  void setInputFocusNode(FocusNode focusNode) {
    if (_inputFocusNode != null) {
      _inputFocusNode!.removeListener(_onFocusChanged);
    }
    _inputFocusNode = focusNode;
    _inputFocusNode!.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    notifyListeners();
  }

  void restoreFocus() {
    _inputFocusNode?.requestFocus();
  }

  void removeFocus() {
    _inputFocusNode?.unfocus();
  }

  @override
  void dispose() {
    _inputFocusNode?.removeListener(_onFocusChanged);
    super.dispose();
  }
}
