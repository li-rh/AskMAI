/// 应用级别的常量定义
class AppConstants {
  // 应用信息
  static const String appName = 'AMAi';
  static const String appVersion = '1.0.0';

  // WebView配置
  static const int webViewLoadTimeoutMs = 30000;
  static const int jsExecutionTimeoutMs = 10000;

  // 提交配置
  static const int maxConcurrentSubmissions = 10;
  static const int submissionTimeoutMs = 15000;

  // 存储配置
  static const String sharedPrefsPrefix = 'askmai_';

  // UI配置
  static const int tabBarHeight = 56;
  static const int inputAreaPadding = 12;

  // 日志
  static const bool enableDebugLogging = true;
}

/// 错误信息
class ErrorMessages {
  static const String noTabSelected = 'No tab selected';
  static const String noTabsAdded = 'No tabs added yet';
  static const String emptyInput = 'Input cannot be empty';
  static const String invalidUrl = 'URL must start with http:// or https://';
  static const String webViewNotFound = 'WebView not found';
  static const String siteConfigNotFound = 'Site configuration not found';
  static const String jsExecutionError = 'JavaScript execution error';
}

/// 成功消息
class SuccessMessages {
  static const String tabAdded = 'Tab added successfully';
  static const String tabRemoved = 'Tab removed';
  static const String messagesSent = 'Messages sent';
}
