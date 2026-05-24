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

  /// WebView控制器（不序列化）
  @JsonKey(ignore: true)
  WebViewController? webViewController;

  LLMTab({
    required this.id,
    required this.url,
    required this.displayName,
    required this.createdAt,
    this.webViewController,
  });

  /// 从JSON创建LLMTab
  factory LLMTab.fromJson(Map<String, dynamic> json) =>
      _$LLMTabFromJson(json);

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$LLMTabToJson(this);

  /// 复制并修改字段
  LLMTab copyWith({
    String? id,
    String? url,
    String? displayName,
    DateTime? createdAt,
    WebViewController? webViewController,
  }) {
    return LLMTab(
      id: id ?? this.id,
      url: url ?? this.url,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      webViewController: webViewController ?? this.webViewController,
    );
  }

  @override
  String toString() =>
      'LLMTab(id: $id, url: $url, displayName: $displayName, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMTab &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url &&
          displayName == other.displayName;

  @override
  int get hashCode =>
      id.hashCode ^ url.hashCode ^ displayName.hashCode;
}
