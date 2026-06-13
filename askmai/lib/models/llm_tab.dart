import 'package:json_annotation/json_annotation.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'llm_tab.g.dart';

/// 代表一个LLM标签页
@JsonSerializable()
class LLMTab {
  /// 唯一标识符
  final String id;

  /// 网站URL
  final String url;

  /// 显示名称
  final String displayName;

  /// 创建时间
  final DateTime createdAt;

  /// 是否启用此标签页（用于广播时是否发送消息）
  final bool isEnabled;

  /// 是否显示此标签页（用于UI中是否显示）
  final bool isDisplayed;

  /// 自定义输入框XPath（为空时使用site_config中的配置）
  final String? customInputXPath;

  /// 自定义提交按钮XPath（为空时使用site_config中的配置）
  final String? customSubmitXPath;

  /// 视口上边距 (px)，用于调整当前tab的网页显示区域
  final int viewportTop;

  /// 视口下边距 (px)
  final int viewportBottom;

  /// 视口左边距 (px)
  final int viewportLeft;

  /// 视口右边距 (px)
  final int viewportRight;

  /// 是否启用视口调整
  final bool viewportEnabled;

  /// WebView控制器（不序列化）
  @JsonKey(includeFromJson: false, includeToJson: false)
  WebViewController? webViewController;

  LLMTab({
    required this.id,
    required this.url,
    required this.displayName,
    required this.createdAt,
    this.isEnabled = true,
    this.isDisplayed = true,
    this.customInputXPath,
    this.customSubmitXPath,
    this.viewportTop = 0,
    this.viewportBottom = 0,
    this.viewportLeft = 0,
    this.viewportRight = 0,
    this.viewportEnabled = true,
    this.webViewController,
  });

  /// 从JSON创建LLMTab
  factory LLMTab.fromJson(Map<String, dynamic> json) => _$LLMTabFromJson(json);

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$LLMTabToJson(this);

  /// 复制并修改字段
  LLMTab copyWith({
    String? id,
    String? url,
    String? displayName,
    DateTime? createdAt,
    bool? isEnabled,
    bool? isDisplayed,
    String? customInputXPath,
    String? customSubmitXPath,
    int? viewportTop,
    int? viewportBottom,
    int? viewportLeft,
    int? viewportRight,
    bool? viewportEnabled,
    WebViewController? webViewController,
  }) {
    return LLMTab(
      id: id ?? this.id,
      url: url ?? this.url,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      isEnabled: isEnabled ?? this.isEnabled,
      isDisplayed: isDisplayed ?? this.isDisplayed,
      customInputXPath: customInputXPath ?? this.customInputXPath,
      customSubmitXPath: customSubmitXPath ?? this.customSubmitXPath,
      viewportTop: viewportTop ?? this.viewportTop,
      viewportBottom: viewportBottom ?? this.viewportBottom,
      viewportLeft: viewportLeft ?? this.viewportLeft,
      viewportRight: viewportRight ?? this.viewportRight,
      viewportEnabled: viewportEnabled ?? this.viewportEnabled,
      webViewController: webViewController ?? this.webViewController,
    );
  }

  @override
  String toString() =>
      'LLMTab(id: $id, url: $url, displayName: $displayName, isEnabled: $isEnabled, isDisplayed: $isDisplayed, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMTab &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url &&
          displayName == other.displayName &&
          isEnabled == other.isEnabled &&
          isDisplayed == other.isDisplayed;

  @override
  int get hashCode =>
      id.hashCode ^
      url.hashCode ^
      displayName.hashCode ^
      isEnabled.hashCode ^
      isDisplayed.hashCode;
}
