# AskMAI Flutter迁移 - 实现计划

**创建日期**：2026-05-24  
**设计基准**：[FLUTTER_MIGRATION_DESIGN.md](./FLUTTER_MIGRATION_DESIGN.md)  
**目标**：逐阶段构建Flutter多LLM客户端

---

## 📋 阶段分解

### 阶段1️⃣：项目脚手架 + 依赖配置（1-2小时）

#### 1.1 创建Flutter项目
```bash
flutter create askmai
cd askmai
```

#### 1.2 配置pubspec.yaml
- ✅ 添加webview_flutter依赖（核心）
- ✅ 添加provider依赖（状态管理）
- ✅ 添加shared_preferences依赖（存储）
- ✅ 添加json_serializable依赖（序列化）
- ✅ 配置assets文件夹

#### 1.3 Android配置
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<!-- 添加互联网权限 -->
<uses-permission android:name="android.permission.INTERNET" />
```

#### 1.4 iOS配置
```swift
// ios/Runner/Info.plist
<!-- 添加NSBonjourServices / NSLocalNetworkUsageDescription -->
```

**交付物**：
- `pubspec.yaml` 完整配置
- Android/iOS平台配置
- 初始项目结构

---

### 阶段2️⃣：Models层实现（1小时）

#### 2.1 创建Models目录结构
```
lib/models/
├── llm_tab.dart
├── site_config.dart
├── submission_result.dart
└── exports.dart
```

#### 2.2 实现LLMTab模型
```dart
// models/llm_tab.dart
@JsonSerializable()
class LLMTab {
  final String id;
  final String url;
  final String displayName;
  final DateTime createdAt;
  
  @JsonKey(ignore: true)
  WebViewController? webViewController;
  
  LLMTab({
    required this.id,
    required this.url,
    required this.displayName,
    required this.createdAt,
  });
  
  factory LLMTab.fromJson(Map<String, dynamic> json) => 
    _$LLMTabFromJson(json);
  
  Map<String, dynamic> toJson() => _$LLMTabToJson(this);
}
```

#### 2.3 实现SiteConfig模型
```dart
// models/site_config.dart
@JsonSerializable()
class SiteConfig {
  final String id;
  final String urlPattern;
  final String inputXPath;
  final String submitXPath;
  final String displayName;
  
  // factory fromJson / toJson ...
}
```

#### 2.4 实现SubmissionResult模型
```dart
// models/submission_result.dart
class SubmissionResult {
  final bool success;
  final String? error;
  final DateTime timestamp;
  final String tabId;
  
  SubmissionResult({
    required this.success,
    this.error,
    required this.timestamp,
    required this.tabId,
  });
}
```

#### 2.5 生成JSON序列化代码
```bash
flutter pub run build_runner build
```

**交付物**：
- 3个完整Models类
- JSON序列化代码自动生成
- exports.dart统一导出

---

### 阶段3️⃣：Services层实现（2-3小时）

#### 3.1 WebViewService
```dart
// services/webview_service.dart
class WebViewService {
  static final WebViewService _instance = WebViewService._internal();
  final Map<String, WebViewController> _webViewControllers = {};
  
  factory WebViewService() => _instance;
  WebViewService._internal();
  
  void addWebView(String tabId, WebViewController controller) {
    _webViewControllers[tabId] = controller;
  }
  
  WebViewController? getWebView(String tabId) => 
    _webViewControllers[tabId];
  
  void removeWebView(String tabId) {
    _webViewControllers.remove(tabId);
  }
  
  List<WebViewController> getAllWebViews() => 
    _webViewControllers.values.toList();
  
  void pauseAll() => _webViewControllers.forEach((_, controller) {
    // 暂停JS执行
  });
  
  void resumeAll() => _webViewControllers.forEach((_, controller) {
    // 恢复JS执行
  });
}
```

#### 3.2 JavascriptService
```dart
// services/javascript_service.dart
class JavascriptService {
  static const String _submitFormJS = '''
    function submitForm(inputXPath, submitXPath, messageText) {
      try {
        const inputElement = document.evaluate(
          inputXPath, document, null,
          XPathResult.FIRST_ORDERED_NODE_TYPE, null
        ).singleNodeValue;
        
        const submitButton = document.evaluate(
          submitXPath, document, null,
          XPathResult.FIRST_ORDERED_NODE_TYPE, null
        ).singleNodeValue;
        
        if (!inputElement || !submitButton) {
          return { success: false, error: 'Elements not found' };
        }
        
        inputElement.value = messageText;
        inputElement.dispatchEvent(new Event('input', { bubbles: true }));
        inputElement.dispatchEvent(new Event('change', { bubbles: true }));
        
        submitButton.click();
        return { success: true, timestamp: Date.now() };
      } catch (e) {
        return { success: false, error: e.message };
      }
    }
  ''';
  
  Future<SubmissionResult> executeSubmit(
    WebViewController controller,
    String inputXPath,
    String submitXPath,
    String message,
    String tabId,
  ) async {
    try {
      final result = await controller.runJavaScript(
        '''
        $inputXPath
        submitForm('$inputXPath', '$submitXPath', '$message')
        '''
      );
      
      // 解析result...
      return SubmissionResult(
        success: true,
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    } catch (e) {
      return SubmissionResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }
}
```

#### 3.3 SiteRegistry
```dart
// services/site_registry.dart
class SiteRegistry {
  static final SiteRegistry _instance = SiteRegistry._internal();
  late Map<String, SiteConfig> _sites;
  
  factory SiteRegistry() => _instance;
  SiteRegistry._internal();
  
  Future<void> loadConfigs() async {
    final configJson = await rootBundle.loadString(
      'assets/site_config.json'
    );
    final decoded = jsonDecode(configJson);
    
    _sites = {};
    for (var site in decoded['sites']) {
      _sites[site['id']] = SiteConfig.fromJson(site);
    }
  }
  
  SiteConfig? getConfigByUrl(String url) {
    for (var config in _sites.values) {
      if (RegExp(config.urlPattern).hasMatch(url)) {
        return config;
      }
    }
    return null;
  }
  
  SiteConfig? getConfigById(String siteId) => _sites[siteId];
}
```

#### 3.4 PreferencesService
```dart
// services/preferences_service.dart
class PreferencesService {
  static const String _tabUrlsKey = 'tab_urls';
  
  Future<void> saveTabUrls(List<LLMTab> tabs) async {
    final prefs = await SharedPreferences.getInstance();
    final urls = jsonEncode(tabs.map((t) => t.toJson()).toList());
    await prefs.setString(_tabUrlsKey, urls);
  }
  
  Future<List<LLMTab>> getTabUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_tabUrlsKey);
    
    if (json == null) return [];
    
    final decoded = jsonDecode(json) as List;
    return decoded.map((t) => LLMTab.fromJson(t)).toList();
  }
  
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
```

**交付物**：
- 4个完整Service类
- 单例模式实现
- 完整的WebView + JS管理接口

---

### 阶段4️⃣：ViewModels层实现（2-3小时）

#### 4.1 TabManagerVM
```dart
// viewmodels/tab_manager_vm.dart
class TabManagerVM extends ChangeNotifier {
  final PreferencesService _prefs;
  
  List<LLMTab> _tabs = [];
  String? _activeTabId;
  
  TabManagerVM(this._prefs);
  
  List<LLMTab> get tabs => _tabs;
  LLMTab? get activeTab => _tabs.firstWhereOrNull(
    (t) => t.id == _activeTabId
  );
  String? get activeTabId => _activeTabId;
  
  void addTab(String url, String displayName) {
    final tab = LLMTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
    _tabs.add(tab);
    if (_activeTabId == null) {
      _activeTabId = tab.id;
    }
    notifyListeners();
    persistTabs();
  }
  
  void removeTab(String tabId) {
    _tabs.removeWhere((t) => t.id == tabId);
    if (_activeTabId == tabId) {
      _activeTabId = _tabs.isNotEmpty ? _tabs.first.id : null;
    }
    notifyListeners();
    persistTabs();
  }
  
  void switchTab(String tabId) {
    if (_tabs.any((t) => t.id == tabId)) {
      _activeTabId = tabId;
      notifyListeners();
    }
  }
  
  Future<void> persistTabs() async {
    await _prefs.saveTabUrls(_tabs);
  }
  
  Future<void> restoreTabs() async {
    _tabs = await _prefs.getTabUrls();
    if (_tabs.isNotEmpty) {
      _activeTabId = _tabs.first.id;
    }
    notifyListeners();
  }
}
```

#### 4.2 InputDistributorVM
```dart
// viewmodels/input_distributor_vm.dart
class InputDistributorVM extends ChangeNotifier {
  final AutomationVM _automationVM;
  
  Map<String, SubmissionResult> _submissionStatus = {};
  bool _isSubmitting = false;
  
  InputDistributorVM(this._automationVM);
  
  bool get isSubmitting => _isSubmitting;
  SubmissionResult? getStatus(String tabId) => 
    _submissionStatus[tabId];
  
  Future<void> broadcastInput(String message) async {
    if (message.trim().isEmpty) return;
    
    _isSubmitting = true;
    notifyListeners();
    
    final tabVM = /* 从Provider获取 */;
    final futures = tabVM.tabs.map((tab) =>
      _automationVM.submitToTab(tab.id, message)
    ).toList();
    
    final results = await Future.wait(futures);
    
    _submissionStatus.clear();
    for (var result in results) {
      _submissionStatus[result.tabId] = result;
    }
    
    _isSubmitting = false;
    notifyListeners();
  }
}
```

#### 4.3 AutomationVM
```dart
// viewmodels/automation_vm.dart
class AutomationVM extends ChangeNotifier {
  final WebViewService _webViewService;
  final JavascriptService _jsService;
  final SiteRegistry _siteRegistry;
  
  AutomationVM(
    this._webViewService,
    this._jsService,
    this._siteRegistry,
  );
  
  Future<SubmissionResult> submitToTab(
    String tabId,
    String message,
    LLMTab tab,
  ) async {
    try {
      final controller = _webViewService.getWebView(tabId);
      if (controller == null) {
        return SubmissionResult(
          success: false,
          error: 'WebView not found',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      
      final siteConfig = _siteRegistry.getConfigByUrl(tab.url);
      if (siteConfig == null) {
        return SubmissionResult(
          success: false,
          error: 'Site config not found',
          timestamp: DateTime.now(),
          tabId: tabId,
        );
      }
      
      return await _jsService.executeSubmit(
        controller,
        siteConfig.inputXPath,
        siteConfig.submitXPath,
        message,
        tabId,
      );
    } catch (e) {
      return SubmissionResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
        tabId: tabId,
      );
    }
  }
}
```

**交付物**：
- 3个完整ViewModel类
- Provider集成
- 并发JS执行逻辑

---

### 阶段5️⃣：UI层实现（4-5小时）

#### 5.1 ChatScreen（主屏幕）
- 搭建Scaffold框架
- 集成TabBar
- 集成WebViewContainer
- 集成InputArea

#### 5.2 TabBar组件
- 水平滚动列表显示tabs
- 点击切换active tab
- 长按/滑动删除tab
- 添加tab按钮

#### 5.3 WebViewContainer组件
- WebViewWidget包装
- JavaScript启用配置
- 页面加载状态
- 错误处理

#### 5.4 InputArea组件
- TextField输入框
- Send按钮
- 加载状态反馈
- 提交结果显示

#### 5.5 辅助组件
- AddTabDialog（添加新标签页）
- ErrorSnackbar（错误提示）
- LoadingIndicator（加载指示符）

**交付物**：
- 完整的UI层实现
- Material Design风格
- 响应式布局
- 完整的用户交互流

---

### 阶段6️⃣：资源和配置（30分钟）

#### 6.1 复制资源文件
```bash
# 从原项目复制
cp ../android/app/src/main/assets/site_config.json ./assets/
```

#### 6.2 配置Android
```gradle
// android/app/build.gradle
android {
    compileSdk 34
    defaultConfig {
        minSdkVersion 24
        targetSdkVersion 34
    }
}
```

#### 6.3 配置iOS
```swift
// ios/Podfile
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

**交付物**：
- assets文件夹配置
- Android/iOS配置完成
- 编译环境就绪

---

### 阶段7️⃣：集成和验证（1-2小时）

#### 7.1 运行build_runner生成代码
```bash
flutter pub run build_runner build
```

#### 7.2 解决依赖冲突
- 检查pub warnings
- 更新lockfile

#### 7.3 编译测试
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

#### 7.4 功能测试
- [ ] 添加标签页
- [ ] 切换标签页
- [ ] 删除标签页
- [ ] 输入并提交
- [ ] 多标签页并发提交
- [ ] 应用重启后恢复标签页

**交付物**：
- 编译通过（无错误）
- APK可生成
- 基本功能验证

---

## 🎯 关键里程碑

| 里程碑 | 状态 | 预计完成 |
|------|------|---------|
| 项目脚手架完成 | ⏳ | 1h |
| Models + Services完成 | ⏳ | 4h |
| ViewModels完成 | ⏳ | 6h |
| UI完成 | ⏳ | 10h |
| 资源配置完成 | ⏳ | 10.5h |
| 编译通过 | ⏳ | 11.5h |
| 功能测试通过 | ⏳ | 12.5-13.5h |

---

## 🔧 工具和环境要求

- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / Xcode
- VS Code + Flutter扩展（推荐）

---

## 📌 注意事项

1. **JSON序列化**：每次修改Model需要运行build_runner重新生成
2. **WebView权限**：确保AndroidManifest.xml包含互联网权限
3. **XPath配置**：site_config.json必须复制到assets文件夹
4. **Provider依赖关系**：注意Services的单例初始化顺序
5. **异常处理**：所有JS执行需要try-catch包装

---

## ✅ 完成标志

项目完成的标志：
- ✅ APK编译成功
- ✅ IPA编译成功
- ✅ 所有功能测试通过
- ✅ 无编译警告或错误
- ✅ 可在真机/模拟器上运行
- ✅ 支持多标签页并发提交

