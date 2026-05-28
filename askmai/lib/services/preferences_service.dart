import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exports.dart';

/// SharedPreferences管理服务
class PreferencesService {
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
      print('Error saving tab URLs: $e');
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
      print('Error reading tab URLs: $e');
      return [];
    }
  }

  /// 保存活跃标签页ID
  Future<void> saveActiveTabId(String tabId) async {
    try {
      await _prefs.setString(_activeTabIdKey, tabId);
    } catch (e) {
      print('Error saving active tab ID: $e');
    }
  }

  /// 读取活跃标签页ID
  Future<String?> getActiveTabId() async {
    try {
      return _prefs.getString(_activeTabIdKey);
    } catch (e) {
      print('Error reading active tab ID: $e');
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
      print('Error saving single tab: $e');
    }
  }

  /// 删除单个标签页
  Future<void> removeTab(String tabId) async {
    try {
      final tabs = await getTabUrls();
      tabs.removeWhere((t) => t.id == tabId);
      await saveTabUrls(tabs);
    } catch (e) {
      print('Error removing tab: $e');
    }
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    try {
      await _prefs.clear();
    } catch (e) {
      print('Error clearing preferences: $e');
    }
  }

  /// 获取所有keys
  Set<String> getKeys() {
    return _prefs.getKeys();
  }

  // ==================== 主题和设置管理 ====================

  static const String _themeModeKey = 'theme_mode';
  static const String _showAppBarKey = 'show_app_bar';

  /// 保存主题模式
  Future<void> setThemeMode(String mode) async {
    try {
      await _prefs.setString(_themeModeKey, mode);
    } catch (e) {
      print('Error saving theme mode: $e');
    }
  }

  /// 读取主题模式
  String? getThemeMode() {
    try {
      return _prefs.getString(_themeModeKey);
    } catch (e) {
      print('Error reading theme mode: $e');
      return null;
    }
  }

  /// 保存 AppBar 可见性
  Future<void> setShowAppBar(bool show) async {
    try {
      await _prefs.setBool(_showAppBarKey, show);
    } catch (e) {
      print('Error saving show app bar: $e');
    }
  }

  /// 读取 AppBar 可见性
  bool? getShowAppBar() {
    try {
      return _prefs.getBool(_showAppBarKey);
    } catch (e) {
      print('Error reading show app bar: $e');
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
      print('Error saving virtual top gap: $e');
    }
  }

  /// 读取虚拟显示顶部间距
  double getVirtualTopGap() {
    try {
      return _prefs.getDouble(_virtualTopGapKey) ?? 0.0;
    } catch (e) {
      print('Error reading virtual top gap: $e');
      return 0.0;
    }
  }

  /// 保存虚拟显示底部间距
  Future<void> setVirtualBottomGap(double gap) async {
    try {
      await _prefs.setDouble(_virtualBottomGapKey, gap);
    } catch (e) {
      print('Error saving virtual bottom gap: $e');
    }
  }

  /// 读取虚拟显示底部间距
  double getVirtualBottomGap() {
    try {
      return _prefs.getDouble(_virtualBottomGapKey) ?? 0.0;
    } catch (e) {
      print('Error reading virtual bottom gap: $e');
      return 0.0;
    }
  }

  @override
  String toString() => 'PreferencesService()';
}
