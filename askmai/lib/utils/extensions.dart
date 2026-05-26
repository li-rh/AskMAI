
/// String扩展方法
extension StringExtension on String {
  /// 检查是否为有效的URL
  bool get isValidUrl {
    try {
      Uri.parse(this);
      return startsWith('http://') || startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  /// 截断字符串
  String truncate({int length = 20, String ellipsis = '...'}) {
    if (this.length <= length) return this;
    return '${substring(0, length)}$ellipsis';
  }

  /// 获取域名
  String get domain {
    try {
      final uri = Uri.parse(this);
      return uri.host;
    } catch (e) {
      return this;
    }
  }
}

/// List<T>扩展方法
extension ListExtension<T> on List<T> {
  /// 获取第一个匹配的元素，如果没有返回null
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }

  /// 获取最后一个匹配的元素，如果没有返回null
  T? lastWhereOrNull(bool Function(T) test) {
    try {
      return lastWhere(test);
    } catch (e) {
      return null;
    }
  }
}

/// DateTime扩展方法
extension DateTimeExtension on DateTime {
  /// 获取格式化的时间字符串
  String get formattedTime {
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }

  /// 检查是否为今天
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// 检查是否为昨天
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}

/// Duration扩展方法
extension DurationExtension on Duration {
  /// 获取格式化的持续时间字符串
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }
}

/// num扩展方法
extension NumExtension on num {
  /// 获取格式化的百分比字符串
  String toPercentage({int decimals = 2}) {
    return '${(this * 100).toStringAsFixed(decimals)}%';
  }
}
