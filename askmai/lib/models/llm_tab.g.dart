// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_tab.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LLMTab _$LLMTabFromJson(Map<String, dynamic> json) => LLMTab(
  id: json['id'] as String,
  url: json['url'] as String,
  displayName: json['displayName'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  isEnabled: json['isEnabled'] as bool? ?? true,
  isDisplayed: json['isDisplayed'] as bool? ?? true,
  customInputXPath: json['customInputXPath'] as String?,
  customSubmitXPath: json['customSubmitXPath'] as String?,
  viewportTop: (json['viewportTop'] as num?)?.toInt() ?? 0,
  viewportBottom: (json['viewportBottom'] as num?)?.toInt() ?? 0,
  viewportLeft: (json['viewportLeft'] as num?)?.toInt() ?? 0,
  viewportRight: (json['viewportRight'] as num?)?.toInt() ?? 0,
  viewportEnabled: json['viewportEnabled'] as bool? ?? true,
);

Map<String, dynamic> _$LLMTabToJson(LLMTab instance) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'displayName': instance.displayName,
  'createdAt': instance.createdAt.toIso8601String(),
  'isEnabled': instance.isEnabled,
  'isDisplayed': instance.isDisplayed,
  'customInputXPath': instance.customInputXPath,
  'customSubmitXPath': instance.customSubmitXPath,
  'viewportTop': instance.viewportTop,
  'viewportBottom': instance.viewportBottom,
  'viewportLeft': instance.viewportLeft,
  'viewportRight': instance.viewportRight,
  'viewportEnabled': instance.viewportEnabled,
};
