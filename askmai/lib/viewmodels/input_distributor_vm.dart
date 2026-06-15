import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/exports.dart';
import 'automation_vm.dart';
import 'tab_manager_vm.dart';

/// 输入分发ViewModel - 管理用户输入和广播
class InputDistributorVM extends ChangeNotifier {
  final AutomationVM _automationVM;
  final TabManagerVM _tabManagerVM;

  final Map<String, SubmissionResult> _submissionStatus = {};
  bool _isSubmitting = false;
  String? _lastBroadcastMessage;

  InputDistributorVM(this._automationVM, this._tabManagerVM);

  // Getters
  bool get isSubmitting => _isSubmitting;
  String? get lastBroadcastMessage => _lastBroadcastMessage;
  Map<String, SubmissionResult> get submissionStatus => _submissionStatus;
  SubmissionResult? getStatus(String tabId) => _submissionStatus[tabId];

  /// 检查是否有最近的提交
  bool hasRecentSubmissions() {
    return _submissionStatus.values.any((result) => result.isRecent());
  }

  /// 获取成功的提交数量
  int getSuccessCount() {
    return _submissionStatus.values.where((r) => r.success).length;
  }

  /// 获取失败的提交数量
  int getFailureCount() {
    return _submissionStatus.values.where((r) => !r.success).length;
  }

  /// 清空提交状态
  void clearSubmissionStatus() {
    _submissionStatus.clear();
    notifyListeners();
  }

  /// 广播输入到所有标签页
  Future<void> broadcastInput(String message) async {
    // 验证输入
    if (message.trim().isEmpty) {
      return;
    }

    _lastBroadcastMessage = message;

    if (_tabManagerVM.tabs.isEmpty) {
      return;
    }

    try {
      _isSubmitting = true;
      notifyListeners();

      // 提交到所有标签页
      final results = await _automationVM.submitToAllTabs(
        message,
        _tabManagerVM,
      );

      // 更新状态
      _submissionStatus.clear();
      for (var result in results) {
        _submissionStatus[result.tabId] = result;
      }

      // 记录统计信息
      _logSubmissionStats();
    } catch (e) {
      _log('Error during broadcast', e);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// 记录提交统计
  void _logSubmissionStats() {
    final total = _submissionStatus.length;
    final success = getSuccessCount();
    final failed = getFailureCount();

    _log('Submission Stats - Total: $total, Success: $success, Failed: $failed');

    for (var entry in _submissionStatus.entries) {
      final result = entry.value;
      final tab = _tabManagerVM.getTab(result.tabId);
      final label = tab?.displayName ?? result.tabId;
      _log('  $label: ${result.getStatusString()}');
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'InputDistributorVM', error: error);
  }

  @override
  String toString() =>
      'InputDistributorVM(isSubmitting: $_isSubmitting, statuses: ${_submissionStatus.length})';
}
