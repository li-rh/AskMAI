import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exports.dart';

/// 网站配置注册表 - 单例模式
/// 从assets/site_config.json加载LLM网站配置
class SiteRegistry {
  static final SiteRegistry _instance = SiteRegistry._internal();

  late Map<String, SiteConfig> _sites;
  bool _isInitialized = false;

  factory SiteRegistry() {
    return _instance;
  }

  SiteRegistry._internal();

  /// 初始化 - 从assets加载配置
  Future<void> loadConfigs() async {
    if (_isInitialized) return;

    try {
      final configJson = await rootBundle.loadString(
        'assets/site_config.json',
      );

      final decoded = jsonDecode(configJson) as Map<String, dynamic>;
      _sites = {};

      if (decoded.containsKey('sites')) {
        final sites = decoded['sites'] as Map<String, dynamic>;
        sites.forEach((key, value) {
          try {
            final siteData = (value as Map<String, dynamic>).cast<String, dynamic>();
            siteData['id'] = key; // 添加id字段
            _sites[key] = SiteConfig.fromJson(siteData);
          } catch (e) {
            print('Failed to parse site config for $key: $e');
          }
        });
      }

      _isInitialized = true;
      print('Loaded ${_sites.length} site configurations');
    } catch (e) {
      print('Error loading site configurations: $e');
      _sites = {};
      _isInitialized = true;
    }
  }

  /// 根据URL获取网站配置
  SiteConfig? getConfigByUrl(String url) {
    for (var config in _sites.values) {
      if (config.matchesUrl(url)) {
        return config;
      }
    }
    return null;
  }

  /// 根据网站ID获取配置
  SiteConfig? getConfigById(String siteId) {
    return _sites[siteId];
  }

  /// 获取所有配置
  List<SiteConfig> getAllConfigs() {
    return _sites.values.toList();
  }

  /// 检查配置是否存在
  bool hasConfig(String siteId) {
    return _sites.containsKey(siteId);
  }

  /// 获取配置数量
  int get configCount => _sites.length;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 清空所有配置
  void clear() {
    _sites.clear();
    _isInitialized = false;
  }

  @override
  String toString() => 'SiteRegistry(count: $configCount, initialized: $isInitialized)';
}
