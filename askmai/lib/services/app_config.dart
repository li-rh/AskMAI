import 'dart:convert';
import 'package:flutter/services.dart';

/// 全局应用程序配置 - 单例模式
/// 从 assets/app_config.json 加载静态配置
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  String _themeMode = 'auto';
  bool _showAppBar = false;
  String _webLoadStrategy = 'sequential';
  String _githubUrl = 'https://github.com/li-rh/AskMAI';

  String get themeMode => _themeMode;
  bool get showAppBar => _showAppBar;
  String get webLoadStrategy => _webLoadStrategy;
  String get githubUrl => _githubUrl;

  /// 加载配置文件
  Future<void> loadConfig() async {
    try {
      final configJson = await rootBundle.loadString('assets/app_config.json');
      final decoded = jsonDecode(configJson) as Map<String, dynamic>;

      _themeMode = decoded['themeMode'] ?? 'auto';
      _showAppBar = decoded['showAppBar'] ?? false;
      _webLoadStrategy = decoded['webLoadStrategy'] ?? 'sequential';
      _githubUrl = decoded['githubUrl'] ?? 'https://github.com/li-rh/AskMAI';
    } catch (e) {
      print('Error loading app config: $e');
    }
  }
}
