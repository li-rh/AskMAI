import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/exports.dart';
import 'viewmodels/exports.dart';
import 'ui/screens/exports.dart';
import 'utils/exports.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 确保系统 UI（状态栏）始终显示
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  // 初始化SharedPreferences
  final prefsService = PreferencesService();
  await prefsService.init();

  // --- 临时调试代码：清空 SharedPreferences 配置 (不会清除 WebView Cookie) ---
  // await prefsService.clearAll();
  // ----------------------------------------------------------------------

  // 初始化SiteRegistry
  final siteRegistry = SiteRegistry();
  await siteRegistry.loadConfigs();

  runApp(MyApp(prefsService: prefsService, siteRegistry: siteRegistry));
}

class MyApp extends StatelessWidget {
  final PreferencesService prefsService;
  final SiteRegistry siteRegistry;

  const MyApp({
    Key? key,
    required this.prefsService,
    required this.siteRegistry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services (单例，全局访问)
        Provider<PreferencesService>.value(value: prefsService),
        Provider<SiteRegistry>.value(value: siteRegistry),
        Provider<WebViewService>(create: (_) => WebViewService()),
        Provider<JavascriptService>(create: (_) => JavascriptService()),
        ChangeNotifierProvider<InputFocusManager>(
          create: (_) => InputFocusManager(),
        ),
        ChangeNotifierProvider<KeyboardVisibilityManager>(
          create: (_) => KeyboardVisibilityManager(),
        ),

        // ViewModels (使用Services)
        ChangeNotifierProvider<TabManagerVM>(
          create: (_) => TabManagerVM(prefsService),
        ),
        ChangeNotifierProvider<AutomationVM>(
          create: (context) => AutomationVM(
            context.read<WebViewService>(),
            context.read<JavascriptService>(),
            siteRegistry,
          ),
        ),
        ChangeNotifierProvider<InputDistributorVM>(
          create: (context) => InputDistributorVM(
            context.read<AutomationVM>(),
            context.read<TabManagerVM>(),
          ),
        ),
        // 应用设置 ViewModel
        ChangeNotifierProvider<AppSettingsVM>(
          create: (_) => AppSettingsVM(prefsService),
        ),
      ],
      child: const _MaterialAppWithTheme(),
    );
  }
}

/// 根据 AppSettingsVM 动态构建 MaterialApp 的主题
class _MaterialAppWithTheme extends StatelessWidget {
  const _MaterialAppWithTheme();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsVM>(
      builder: (context, settingsVM, _) {
        // 根据设置获取主题
        final themeMode = _getThemeModeFromString(settingsVM.themeMode);

        return MaterialApp(
          title: 'AskMAI',
          theme: AppThemeConfig.buildLightTheme(),
          darkTheme: AppThemeConfig.buildDarkTheme(),
          themeMode: themeMode,
          home: const ChatScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  /// 将字符串转换为 ThemeMode
  ThemeMode _getThemeModeFromString(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'auto':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}
