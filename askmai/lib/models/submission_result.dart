/// JavaScript提交操作的结果
class SubmissionResult {
  /// 提交是否成功
  final bool success;

  /// 错误信息（如果有）
  final String? error;

  /// 提交时间戳
  final DateTime timestamp;

  /// 标签页ID
  final String tabId;

  SubmissionResult({
    required this.success,
    this.error,
    required this.timestamp,
    required this.tabId,
  });

  /// 检查结果是否为最近的（5秒内）
  bool isRecent() {
    return DateTime.now().difference(timestamp).inSeconds < 5;
  }

  /// 获取状态字符串
  String getStatusString() {
    if (success) {
      return 'Success';
    } else {
      return 'Failed: ${error ?? "Unknown error"}';
    }
  }

  @override
  String toString() =>
      'SubmissionResult(success: $success, tabId: $tabId, timestamp: $timestamp, error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubmissionResult &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          tabId == other.tabId;

  @override
  int get hashCode => success.hashCode ^ tabId.hashCode;
}
