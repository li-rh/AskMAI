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
  isDisplay: json['isDisplay'] as bool? ?? true,
  isEnabled: json['isEnabled'] as bool? ?? true,
  viewportTop: (json['viewportTop'] as num?)?.toInt() ?? 0,
  viewportBottom: (json['viewportBottom'] as num?)?.toInt() ?? 0,
  viewportLeft: (json['viewportLeft'] as num?)?.toInt() ?? 0,
  viewportRight: (json['viewportRight'] as num?)?.toInt() ?? 0,
  viewportEnabled: json['viewportEnabled'] as bool? ?? true,
  strategy: json['strategy'] as String?,
  userAgent: json['userAgent'] as String?,
  copyButtonXPath: json['copyButtonXPath'] as String?,
  responseXPath: json['responseXPath'] as String?,
  answerContentXPath: json['answerContentXPath'] as String?,
);

Map<String, dynamic> _$SiteConfigToJson(SiteConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'urlPattern': instance.urlPattern,
      'inputXPath': instance.inputXPath,
      'submitXPath': instance.submitXPath,
      'displayName': instance.displayName,
      'isDisplay': instance.isDisplay,
      'isEnabled': instance.isEnabled,
      'viewportTop': instance.viewportTop,
      'viewportBottom': instance.viewportBottom,
      'viewportLeft': instance.viewportLeft,
      'viewportRight': instance.viewportRight,
      'viewportEnabled': instance.viewportEnabled,
      'strategy': instance.strategy,
      'userAgent': instance.userAgent,
      'copyButtonXPath': instance.copyButtonXPath,
      'responseXPath': instance.responseXPath,
      'answerContentXPath': instance.answerContentXPath,
    };
