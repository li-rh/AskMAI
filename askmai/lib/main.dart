import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/exports.dart';
import 'viewmodels/exports.dart';
import 'ui/screens/exports.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化SharedPreferences
  final prefsService = PreferencesService();
  await prefsService.init();

  // 初始化SiteRegistry
  final siteRegistry = SiteRegistry();
  await siteRegistry.loadConfigs();

  runApp(MyApp(
    prefsService: prefsService,
    siteRegistry: siteRegistry,
  ));
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
        Provider<WebViewService>(
          create: (_) => WebViewService(),
        ),
        Provider<JavascriptService>(
          create: (_) => JavascriptService(),
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
      ],
      child: MaterialApp(
        title: 'AskMAI',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 1,
            centerTitle: false,
          ),
        ),
        home: const ChatScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
