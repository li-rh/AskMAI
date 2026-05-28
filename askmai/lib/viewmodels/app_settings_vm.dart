import 'package:flutter/material.dart';
import '../services/exports.dart';

/// 应用全局设置 ViewModel
/// 管理主题、AppBar可见性等全局设置
class AppSettingsVM extends ChangeNotifier {
  final PreferencesService _prefsService;

  // 主题模式: 'light', 'dark', 'auto'
  late String _themeMode;
  bool _showAppBar = true;

  String get themeMode => _themeMode;
  bool get showAppBar => _showAppBar;

  // 虚拟显示设置
  double _virtualTopGap = 0.0;
  double _virtualBottomGap = 0.0;

  double get virtualTopGap => _virtualTopGap;
  double get virtualBottomGap => _virtualBottomGap;

  AppSettingsVM(this._prefsService) {
    _initSettings();
  }

  /// 从 SharedPreferences 初始化设置
  Future<void> _initSettings() async {
    _themeMode = _prefsService.getThemeMode() ?? 'light';
    _showAppBar = _prefsService.getShowAppBar() ?? true;
    _virtualTopGap = _prefsService.getVirtualTopGap();
    _virtualBottomGap = _prefsService.getVirtualBottomGap();
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
    _themeMode = 'light';
    _showAppBar = true;
    await _prefsService.setThemeMode(_themeMode);
    await _prefsService.setShowAppBar(_showAppBar);
    notifyListeners();
  }
}
