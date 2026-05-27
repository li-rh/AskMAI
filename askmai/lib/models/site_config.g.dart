// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'site_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SiteConfig _$SiteConfigFromJson(Map<String, dynamic> json) => SiteConfig(
  id: json['id'] as String,
  urlPattern: json['urlPattern'] as String,
  inputXPath: json['inputXPath'] as String,
  submitXPath: json['submitXPath'] as String,
  displayName: json['displayName'] as String,
  viewportTop: (json['viewportTop'] as num?)?.toInt() ?? 0,
  viewportBottom: (json['viewportBottom'] as num?)?.toInt() ?? 0,
  viewportLeft: (json['viewportLeft'] as num?)?.toInt() ?? 0,
  viewportRight: (json['viewportRight'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SiteConfigToJson(SiteConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'urlPattern': instance.urlPattern,
      'inputXPath': instance.inputXPath,
      'submitXPath': instance.submitXPath,
      'displayName': instance.displayName,
      'viewportTop': instance.viewportTop,
      'viewportBottom': instance.viewportBottom,
      'viewportLeft': instance.viewportLeft,
      'viewportRight': instance.viewportRight,
    };
