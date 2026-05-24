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

  SiteConfig({
    required this.id,
    required this.urlPattern,
    required this.inputXPath,
    required this.submitXPath,
    required this.displayName,
  });

  /// 从JSON创建SiteConfig
  factory SiteConfig.fromJson(Map<String, dynamic> json) =>
      _$SiteConfigFromJson(json);

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$SiteConfigToJson(this);

  /// 检查URL是否匹配此网站配置
  bool matchesUrl(String url) {
    try {
      final regex = RegExp(urlPattern);
      return regex.hasMatch(url);
    } catch (e) {
      return false;
    }
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
