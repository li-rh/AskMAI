import 'package:json_annotation/json_annotation.dart';

part 'site_config.g.dart';

/// LLM网站配置 - 存储XPath和其他自动化信息
@JsonSerializable()
class SiteConfig {
  /// 网站ID (例如: 'chatgpt', 'claude', 'douban')
  final String id;

  /// URL正则表达式，用于匹配网站
  final String urlPattern;

  /// 输入字段的XPath表达式
  final String inputXPath;

  /// 提交按钮的XPath表达式
  final String submitXPath;

  /// 显示名称
  final String displayName;

  /// 是否默认显示
  final bool isDisplay;

  /// 是否默认启用
  final bool isEnabled;

  /// 视口上边距 (px)，用于调整网页显示区域
  final int viewportTop;

  /// 视口下边距 (px)
  final int viewportBottom;

  /// 视口左边距 (px)
  final int viewportLeft;

  /// 视口右边距 (px)
  final int viewportRight;

  /// 是否启用视口调整
  final bool viewportEnabled;

  /// 注入策略名称 (例如: 'dom_input', 'exec_command', 'react_slate')
  final String? strategy;

  /// 自定义 UserAgent (为空时使用全局 UserAgent)
  final String? userAgent;

  /// 复制按钮的XPath表达式（用于提取AI回答，点击触发站点复制逻辑）
  final String? copyButtonXPath;

  /// AI回答内容的XPath表达式（innerText回退方案）
  final String? responseXPath;

  SiteConfig({
    required this.id,
    required this.urlPattern,
    required this.inputXPath,
    required this.submitXPath,
    required this.displayName,
    this.isDisplay = true,
    this.isEnabled = true,
    this.viewportTop = 0,
    this.viewportBottom = 0,
    this.viewportLeft = 0,
    this.viewportRight = 0,
    this.viewportEnabled = true,
    this.strategy,
    this.userAgent,
    this.copyButtonXPath,
    this.responseXPath,
  });

  /// 从JSON创建SiteConfig
  factory SiteConfig.fromJson(Map<String, dynamic> json) =>
      _$SiteConfigFromJson(json);

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$SiteConfigToJson(this);

  /// 检查URL是否匹配此网站配置
  bool matchesUrl(String url) {
    return url.startsWith(urlPattern);
  }

  @override
  String toString() =>
      'SiteConfig(id: $id, displayName: $displayName, urlPattern: $urlPattern)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiteConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          urlPattern == other.urlPattern;

  @override
  int get hashCode => id.hashCode ^ urlPattern.hashCode;
}
