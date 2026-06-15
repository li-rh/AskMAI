import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exports.dart';

/// SharedPreferences管理服务 - 单例模式
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();

  factory PreferencesService() {
    return _instance;
  }

  PreferencesService._internal();

  static const String _tabUrlsKey = 'tab_urls';
  static const String _activeTabIdKey = 'active_tab_id';

  late SharedPreferences _prefs;

  /// 初始化服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 保存所有标签页
  Future<void> saveTabUrls(List<LLMTab> tabs) async {
    try {
      final jsonList = tabs.map((tab) => tab.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_tabUrlsKey, jsonString);
    } catch (e) {
      _log('Error saving tab URLs', e);
    }
  }

  /// 读取所有标签页
  Future<List<LLMTab>> getTabUrls() async {
    try {
      final jsonString = _prefs.getString(_tabUrlsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(jsonString) as List;
      return decoded
          .map((tab) => LLMTab.fromJson(tab as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('Error reading tab URLs', e);
      return [];
    }
  }

  /// 保存活跃标签页ID
  Future<void> saveActiveTabId(String tabId) async {
    try {
      await _prefs.setString(_activeTabIdKey, tabId);
    } catch (e) {
      _log('Error saving active tab ID', e);
    }
  }

  /// 读取活跃标签页ID
  Future<String?> getActiveTabId() async {
    try {
      return _prefs.getString(_activeTabIdKey);
    } catch (e) {
      _log('Error reading active tab ID', e);
      return null;
    }
  }

  /// 保存单个标签页
  Future<void> saveSingleTab(LLMTab tab) async {
    try {
      final tabs = await getTabUrls();
      tabs.removeWhere((t) => t.id == tab.id);
      tabs.add(tab);
      await saveTabUrls(tabs);
    } catch (e) {
      _log('Error saving single tab', e);
    }
  }

  /// 删除单个标签页
  Future<void> removeTab(String tabId) async {
    try {
      final tabs = await getTabUrls();
      tabs.removeWhere((t) => t.id == tabId);
      await saveTabUrls(tabs);
    } catch (e) {
      _log('Error removing tab', e);
    }
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    try {
      await _prefs.clear();
    } catch (e) {
      _log('Error clearing preferences', e);
    }
  }

  /// 获取所有keys
  Set<String> getKeys() {
    return _prefs.getKeys();
  }

  // ==================== 自定义网站配置 ====================
  static const String _customSiteConfigKey = 'custom_site_config';

  /// 保存自定义网站配置JSON
  Future<void> saveCustomSiteConfig(String jsonStr) async {
    try {
      await _prefs.setString(_customSiteConfigKey, jsonStr);
    } catch (e) {
      _log('Error saving custom site config', e);
    }
  }

  /// 读取自定义网站配置JSON
  String? getCustomSiteConfig() {
    try {
      return _prefs.getString(_customSiteConfigKey);
    } catch (e) {
      _log('Error reading custom site config', e);
      return null;
    }
  }

  // ==================== 主题和设置管理 ====================

  static const String _themeModeKey = 'theme_mode';
  static const String _showAppBarKey = 'show_app_bar';
  static const String _webLoadStrategyKey = 'web_load_strategy';

  /// 保存网页加载策略
  Future<void> setWebLoadStrategy(String strategy) async {
    try {
      await _prefs.setString(_webLoadStrategyKey, strategy);
    } catch (e) {
      _log('Error saving web load strategy', e);
    }
  }

  /// 读取网页加载策略
  String? getWebLoadStrategy() {
    try {
      return _prefs.getString(_webLoadStrategyKey);
    } catch (e) {
      _log('Error reading web load strategy', e);
      return null;
    }
  }

  /// 保存主题模式
  Future<void> setThemeMode(String mode) async {
    try {
      await _prefs.setString(_themeModeKey, mode);
    } catch (e) {
      _log('Error saving theme mode', e);
    }
  }

  /// 读取主题模式
  String? getThemeMode() {
    try {
      return _prefs.getString(_themeModeKey);
    } catch (e) {
      _log('Error reading theme mode', e);
      return null;
    }
  }

  /// 保存 AppBar 可见性
  Future<void> setShowAppBar(bool show) async {
    try {
      await _prefs.setBool(_showAppBarKey, show);
    } catch (e) {
      _log('Error saving show app bar', e);
    }
  }

  /// 读取 AppBar 可见性
  bool? getShowAppBar() {
    try {
      return _prefs.getBool(_showAppBarKey);
    } catch (e) {
      _log('Error reading show app bar', e);
      return null;
    }
  }

  // ==================== 聚合设置 ====================

  static const String _lastAggregateTargetIdKey = 'last_aggregate_target_id';

  Future<void> setLastAggregateTargetId(String tabId) async {
    try {
      await _prefs.setString(_lastAggregateTargetIdKey, tabId);
    } catch (e) {
      _log('Error saving last aggregate target ID', e);
    }
  }

  String? getLastAggregateTargetId() {
    try {
      return _prefs.getString(_lastAggregateTargetIdKey);
    } catch (e) {
      _log('Error reading last aggregate target ID', e);
      return null;
    }
  }

  // ==================== 虚拟显示设置 ====================

  static const String _virtualTopGapKey = 'virtual_top_gap';
  static const String _virtualBottomGapKey = 'virtual_bottom_gap';

  /// 保存虚拟显示顶部间距
  Future<void> setVirtualTopGap(double gap) async {
    try {
      await _prefs.setDouble(_virtualTopGapKey, gap);
    } catch (e) {
      _log('Error saving virtual top gap', e);
    }
  }

  /// 读取虚拟显示顶部间距
  double getVirtualTopGap() {
    try {
      return _prefs.getDouble(_virtualTopGapKey) ?? 0.0;
    } catch (e) {
      _log('Error reading virtual top gap', e);
      return 0.0;
    }
  }

  /// 保存虚拟显示底部间距
  Future<void> setVirtualBottomGap(double gap) async {
    try {
      await _prefs.setDouble(_virtualBottomGapKey, gap);
    } catch (e) {
      _log('Error saving virtual bottom gap', e);
    }
  }

  /// 读取虚拟显示底部间距
  double getVirtualBottomGap() {
    try {
      return _prefs.getDouble(_virtualBottomGapKey) ?? 0.0;
    } catch (e) {
      _log('Error reading virtual bottom gap', e);
      return 0.0;
    }
  }

  void _log(String message, [Object? error]) {
    developer.log(message, name: 'PreferencesService', error: error);
  }

  @override
  String toString() => 'PreferencesService()';
}
