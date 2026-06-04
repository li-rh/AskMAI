import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exports.dart';
import 'preferences_service.dart';

/// 网站配置注册表 - 单例模式
/// 从assets/site_config.json加载LLM网站配置
class SiteRegistry {
  static final SiteRegistry _instance = SiteRegistry._internal();

  late Map<String, SiteConfig> _sites;
  String? _userAgent;
  bool _isInitialized = false;

  factory SiteRegistry() {
    return _instance;
  }

  SiteRegistry._internal();

  /// 获取当前全局 UserAgent
  String get userAgent => _userAgent ?? 'Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36';

  /// 初始化 - 从assets加载配置并与SharedPreferences自定义配置合并
  Future<void> loadConfigs() async {
    if (_isInitialized) return;

    try {
      // 1. 加载 assets 默认配置
      final configJson = await rootBundle.loadString(
        'assets/site_config.json',
      );

      final decoded = jsonDecode(configJson) as Map<String, dynamic>;
      _sites = {};
      _userAgent = decoded['userAgent'] as String?;

      if (decoded.containsKey('sites')) {
        final sites = decoded['sites'] as Map<String, dynamic>;
        sites.forEach((key, value) {
          try {
            final siteData = (value as Map<String, dynamic>).cast<String, dynamic>();
            siteData['id'] = key; // 添加id字段
            _sites[key] = SiteConfig.fromJson(siteData);
          } catch (e) {
            print('Failed to parse default site config for $key: $e');
          }
        });
      }

      // 2. 加载 SharedPreferences 中的自定义配置并进行合并
      try {
        final customPrefs = PreferencesService();
        final customJson = customPrefs.getCustomSiteConfig();
        if (customJson != null && customJson.trim().isNotEmpty) {
          final customDecoded = jsonDecode(customJson) as Map<String, dynamic>;
          if (customDecoded.containsKey('userAgent')) {
            _userAgent = customDecoded['userAgent'] as String?;
          }
          if (customDecoded.containsKey('sites')) {
            final customSites = customDecoded['sites'] as Map<String, dynamic>;
            customSites.forEach((key, value) {
              try {
                final siteData = (value as Map<String, dynamic>).cast<String, dynamic>();
                siteData['id'] = key; // 添加id字段
                _sites[key] = SiteConfig.fromJson(siteData);
              } catch (e) {
                print('Failed to parse custom site config for $key: $e');
              }
            });
          }
        }
      } catch (e) {
        print('Error loading or merging custom site configurations: $e');
      }

      _isInitialized = true;
      print('Loaded ${_sites.length} site configurations. Global UserAgent: $userAgent');
    } catch (e) {
      print('Error loading site configurations: $e');
      _sites = {};
      _isInitialized = true;
    }
  }

  /// 重新加载配置
  Future<void> reloadConfigs() async {
    _isInitialized = false;
    await loadConfigs();
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

  /// 将当前所有配置序列化为Map (匹配 site_config.json 结构)
  /// 可以传入 activeTabs，以使导出的 isDisplay 与当前 UI 中的开关状态保持同步，且能把 UI 手动添加的自定义 tab 导出为配置
  Map<String, dynamic> toMap([List<LLMTab>? activeTabs]) {
    final sitesMap = <String, dynamic>{};
    
    // 1. 序列化当前已注册的站点配置，并同步 UI 修改的值
    _sites.forEach((key, value) {
      final jsonVal = value.toJson();
      if (activeTabs != null) {
        try {
          final matchingTab = activeTabs.firstWhere(
            (tab) => tab.displayName == value.displayName,
          );
          
          jsonVal['urlPattern'] = matchingTab.url;
          jsonVal['isDisplay'] = matchingTab.isDisplayed;
          jsonVal['viewportTop'] = matchingTab.viewportTop;
          jsonVal['viewportBottom'] = matchingTab.viewportBottom;
          jsonVal['viewportLeft'] = matchingTab.viewportLeft;
          jsonVal['viewportRight'] = matchingTab.viewportRight;
          jsonVal['viewportDisabled'] = matchingTab.viewportDisabled;
          
          // 如果实例覆盖了默认 XPath，将其同步写入全局字段
          if (matchingTab.customInputXPath != null) {
            jsonVal['inputXPath'] = matchingTab.customInputXPath;
          }
          if (matchingTab.customSubmitXPath != null) {
            jsonVal['submitXPath'] = matchingTab.customSubmitXPath;
          }
        } catch (_) {
          // 未匹配到则保留原样
        }
      }
      sitesMap[key] = jsonVal;
    });

    // 2. 将 UI 中手动添加但在 _sites 中不存在的自定义 tab 作为配置一并导出
    if (activeTabs != null) {
      for (final tab in activeTabs) {
        final existsInRegistry = _sites.values.any(
          (config) => config.displayName == tab.displayName,
        );
        if (!existsInRegistry) {
          final cleanName = tab.displayName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          final baseKey = cleanName.isEmpty ? 'custom_${tab.id.substring(0, 8)}' : cleanName;

          // 解决 Key 冲突：若生成的 key 在 sitesMap 中已存在，则循环递增后缀
          var siteKey = baseKey;
          var counter = 1;
          while (sitesMap.containsKey(siteKey)) {
            siteKey = '${baseKey}_$counter';
            counter++;
          }

          // 生成一个临时的 site config JSON
          sitesMap[siteKey] = {
            'id': siteKey,
            'urlPattern': tab.url,
            'inputXPath': tab.customInputXPath ?? '',
            'submitXPath': tab.customSubmitXPath ?? '',
            'displayName': tab.displayName,
            'isDisplay': tab.isDisplayed,
            'viewportTop': tab.viewportTop,
            'viewportBottom': tab.viewportBottom,
            'viewportLeft': tab.viewportLeft,
            'viewportRight': tab.viewportRight,
            'viewportDisabled': tab.viewportDisabled,
            'strategy': 'generic',
          };
        }
      }
    }

    return {
      'userAgent': userAgent,
      'sites': sitesMap,
    };
  }

  /// 清空所有配置
  void clear() {
    _sites.clear();
    _userAgent = null;
    _isInitialized = false;
  }

  @override
  String toString() => 'SiteRegistry(count: $configCount, initialized: $isInitialized, userAgent: $userAgent)';
}
