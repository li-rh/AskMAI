import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/exports.dart';

/// 应用全局设置 ViewModel
/// 管理主题、AppBar可见性等全局设置
class AppSettingsVM extends ChangeNotifier {
  final PreferencesService _prefsService;

  // 主题模式: 'light', 'dark', 'auto'
  late String _themeMode;
  bool _showAppBar = false;
  // 网页加载策略: 'concurrent', 'sequential', 'lazy'
  late String _webLoadStrategy;
  String _appVersion = '1.0.0';

  String get themeMode => _themeMode;
  bool get showAppBar => _showAppBar;
  String get webLoadStrategy => _webLoadStrategy;
  String get appVersion => _appVersion;

  // 虚拟显示设置
  double _virtualTopGap = 0.0;
  double _virtualBottomGap = 0.0;

  double get virtualTopGap => _virtualTopGap;
  double get virtualBottomGap => _virtualBottomGap;

  AppSettingsVM(this._prefsService) {
    final appConfig = AppConfig();
    _themeMode = _prefsService.getThemeMode() ?? appConfig.themeMode;
    _showAppBar = _prefsService.getShowAppBar() ?? appConfig.showAppBar;
    _webLoadStrategy = _prefsService.getWebLoadStrategy() ?? appConfig.webLoadStrategy;
    _virtualTopGap = _prefsService.getVirtualTopGap();
    _virtualBottomGap = _prefsService.getVirtualBottomGap();
    _initSettings();
  }

  /// 从 SharedPreferences 初始化设置
  Future<void> _initSettings() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      notifyListeners();
    } catch (e) {
      developer.log('Error loading package info', name: 'AppSettingsVM', error: e);
    }
  }

  /// 设置网页加载策略
  Future<void> setWebLoadStrategy(String strategy) async {
    if (_webLoadStrategy == strategy) return;
    _webLoadStrategy = strategy;
    await _prefsService.setWebLoadStrategy(strategy);
    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(String mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefsService.setThemeMode(mode);
    notifyListeners();
  }

  /// 切换 AppBar 可见性
  Future<void> toggleAppBar() async {
    _showAppBar = !_showAppBar;
    await _prefsService.setShowAppBar(_showAppBar);
    notifyListeners();
  }

  /// 设置虚拟显示间距
  Future<void> setVirtualDisplay({
    required double topGap,
    required double bottomGap,
  }) async {
    _virtualTopGap = topGap;
    _virtualBottomGap = bottomGap;
    await _prefsService.setVirtualTopGap(topGap);
    await _prefsService.setVirtualBottomGap(bottomGap);
    notifyListeners();
  }

  /// 设置 AppBar 可见性
  Future<void> setShowAppBar(bool show) async {
    if (_showAppBar == show) return;
    _showAppBar = show;
    await _prefsService.setShowAppBar(show);
    notifyListeners();
  }

  /// 重置所有设置到默认值
  Future<void> resetToDefaults() async {
    final appConfig = AppConfig();
    _themeMode = appConfig.themeMode;
    _showAppBar = appConfig.showAppBar;
    _webLoadStrategy = appConfig.webLoadStrategy;
    await _prefsService.setThemeMode(_themeMode);
    await _prefsService.setShowAppBar(_showAppBar);
    await _prefsService.setWebLoadStrategy(_webLoadStrategy);
    notifyListeners();
  }
}
