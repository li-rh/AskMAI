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
};
