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
);

Map<String, dynamic> _$LLMTabToJson(LLMTab instance) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'displayName': instance.displayName,
  'createdAt': instance.createdAt.toIso8601String(),
};
