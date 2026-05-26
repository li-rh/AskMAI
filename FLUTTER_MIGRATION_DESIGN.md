# AskMAI Flutter迁移设计文档

**日期**：2026-05-24  
**状态**：等待用户审核  
**目标**：从Kotlin Android迁移到Flutter (Dart)，保持核心功能不变

---

## 📌 概述

### 项目背景
- **现状**：Kotlin + Android WebView实现的多LLM标签页客户端
- **目标**：迁移到Flutter，支持Android和iOS
- **动机**：更快的开发速度、跨平台支持、较小学习曲线

### 关键约束
- 保持WebView + JavaScript自动化架构不变
- 使用Provider + MVVM架构模式
- 本地数据使用SharedPreferences
- Material Design UI框架

---

## 🏗️ 架构设计

### 分层模型

```
┌─────────────────────────────────────┐
│     UI Layer (Widgets)              │
│  ┌─────────────────────────────┐   │
│  │ ChatScreen                  │   │
│  │ ├─ TabBar                   │   │
│  │ ├─ WebViewContainer         │   │
│  │ └─ InputArea                │   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│  ViewModel Layer (Provider)         │
│  ┌─────────────────────────────┐   │
│  │ TabManagerVM                │   │
│  │ InputDistributorVM          │   │
│  │ AutomationVM                │   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│  Service Layer                      │
│  ┌─────────────────────────────┐   │
│  │ WebViewService              │   │
│  │ JavascriptService           │   │
│  │ SiteRegistry                │   │
│  │ PreferencesService          │   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│  Data Layer (Models)                │
│  ├─ LLMTab                          │
│  ├─ SiteConfig                      │
│  └─ SubmissionResult                │
└─────────────────────────────────────┘
```

### 项目文件结构

```
AskMAI/
├── android/                          # Android原生代码
│   └── app/src/main/AndroidManifest.xml  # 权限声明（互联网）
├── ios/                              # iOS原生代码
│   └── Runner/Info.plist             # iOS配置
├── lib/
│   ├── main.dart                     # 应用入口 + MultiProvider
│   │
│   ├── models/
│   │   ├── llm_tab.dart              # 标签页模型
│   │   │   └── @JsonSerializable
│   │   ├── site_config.dart          # 网站配置（XPath映射）
│   │   │   └── fromJson / toJson
│   │   └── submission_result.dart    # JS执行结果
│   │
│   ├── viewmodels/
│   │   ├── tab_manager_vm.dart       # 标签页管理（增删改查）
│   │   ├── input_distributor_vm.dart # 输入分发与广播
│   │   └── automation_vm.dart        # 自动化引擎（JS注入）
│   │
│   ├── services/
│   │   ├── webview_service.dart      # WebView实例管理
│   │   ├── javascript_service.dart   # JS执行桥接
│   │   ├── site_registry.dart        # 网站配置加载与查询
│   │   └── preferences_service.dart  # SharedPreferences管理
│   │
│   ├── ui/
│   │   ├── screens/
│   │   │   └── chat_screen.dart      # 主屏幕（布局 + 逻辑）
│   │   └── widgets/
│   │       ├── tab_bar.dart          # 标签栏组件
│   │       ├── webview_container.dart# WebView容器
│   │       └── input_area.dart       # 输入框 + 发送按钮
│   │
│   ├── assets/
│   │   └── site_config.json          # LLM网站XPath配置（复用）
│   │
│   └── utils/
│       ├── constants.dart            # 常量定义
│       └── extensions.dart           # 扩展方法
│
├── pubspec.yaml                      # 依赖声明
├── FLUTTER_MIGRATION_DESIGN.md       # 本文档
└── FLUTTER_DEVELOPMENT_GUIDE.md      # 开发指南（后续生成）
```

---

## 🔑 核心组件设计

### 1. 模型层 (Models)

#### `llm_tab.dart`
```dart
@JsonSerializable()
class LLMTab {
  final String id;
  final String url;
  final String displayName;
  final DateTime createdAt;
  
  // WebViewController不需要序列化
  @JsonKey(ignore: true)
  WebViewController? webViewController;
  
  // 字段...
}
```
- **职责**：代表一个LLM标签页
- **序列化**：支持JSON序列化，便于SharedPreferences存储
- **生命周期**：创建 → 加载 → 活跃/非活跃 → 关闭

#### `site_config.dart`
```dart
@JsonSerializable()
class SiteConfig {
  final String id;                    // chatgpt, claude, douban等
  final String urlPattern;            // 正则表达式
  final String inputXPath;
  final String submitXPath;
  final String displayName;
}
```
- **职责**：存储每个LLM网站的XPath配置
- **来源**：从`assets/site_config.json`加载（复用原配置）

#### `submission_result.dart`
```dart
class SubmissionResult {
  final bool success;
  final String? error;
  final DateTime timestamp;
  final String tabId;
}
```
- **职责**：记录JS执行结果
- **用途**：UI反馈、错误追踪、性能监控

---

### 2. Service层

#### `webview_service.dart`
```dart
class WebViewService {
  // Map<tabId, WebViewController>
  final _webViewControllers = <String, WebViewController>{};
  
  void addWebView(String tabId, WebViewController controller);
  WebViewController? getWebView(String tabId);
  void removeWebView(String tabId);
  List<WebViewController> getAllWebViews();
  void pauseAll() / resumeAll();  // 生命周期管理
}
```
- **职责**：管理多个WebView实例
- **关键方法**：
  - 添加/移除WebView
  - 获取指定标签的WebViewController
  - 生命周期暂停/恢复

#### `javascript_service.dart`
```dart
class JavascriptService {
  // 单一、可复用的JS函数（从Kotlin版本复用）
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
  );
}
```
- **职责**：注入和执行JavaScript
- **复用性**：JS代码与原Kotlin版本完全相同

#### `site_registry.dart`
```dart
class SiteRegistry {
  static final _instance = SiteRegistry._internal();
  
  late Map<String, SiteConfig> _sites;
  
  Future<void> loadConfigs();
  SiteConfig? getConfigByUrl(String url);
  SiteConfig? getConfigById(String siteId);
}
```
- **职责**：加载和查询LLM网站配置
- **初始化**：应用启动时从`assets/site_config.json`加载

#### `preferences_service.dart`
```dart
class PreferencesService {
  Future<void> saveTabUrls(List<LLMTab> tabs);
  Future<List<String>> getTabUrls();
  Future<void> clearAll();
}
```
- **职责**：提供SharedPreferences的便捷接口
- **数据**：存储Tab URLs以便应用重启后恢复

---

### 3. ViewModel层 (Provider)

#### `tab_manager_vm.dart`
```dart
class TabManagerVM extends ChangeNotifier {
  List<LLMTab> _tabs = [];
  String? _activeTabId;
  
  List<LLMTab> get tabs => _tabs;
  LLMTab? get activeTab => _tabs.firstWhere(
    (t) => t.id == _activeTabId, orElse: () => null
  );
  
  void addTab(String url);
  void removeTab(String tabId);
  void switchTab(String tabId);
  void persistTabs();  // 保存到SharedPreferences
  Future<void> restoreTabs();  // 从SharedPreferences恢复
  
  @override
  void notifyListeners();  // UI自动更新
}
```
- **职责**：标签页生命周期管理
- **状态通知**：通过Provider向UI推送更新

#### `input_distributor_vm.dart`
```dart
class InputDistributorVM extends ChangeNotifier {
  Map<String, SubmissionResult> _submissionStatus = {};
  
  Future<void> broadcastInput(String message);  // 核心方法
  
  SubmissionResult? getStatus(String tabId);
  bool get isSubmitting => _submissionStatus.values
    .any((r) => r.timestamp.isAfter(/* recent time */));
}
```
- **职责**：
  1. 捕获用户输入
  2. 分发到所有活跃标签页
  3. 管理提交状态和反馈
- **并发处理**：
  ```dart
  Future.wait([
    jsService.executeSubmit(webView1, ...),
    jsService.executeSubmit(webView2, ...),
    jsService.executeSubmit(webView3, ...),
  ]);
  ```

#### `automation_vm.dart`
```dart
class AutomationVM extends ChangeNotifier {
  Future<SubmissionResult> submitToTab(
    String tabId,
    String message,
  ) async {
    // 1. 获取WebViewController
    final controller = webViewService.getWebView(tabId);
    
    // 2. 查询网站配置
    final tab = /* from TabManagerVM */;
    final siteConfig = siteRegistry.getConfigByUrl(tab.url);
    
    // 3. 执行JS注入
    final result = await jsService.executeSubmit(
      controller,
      siteConfig.inputXPath,
      siteConfig.submitXPath,
      message,
    );
    
    notifyListeners();
    return result;
  }
}
```
- **职责**：自动化引擎的核心逻辑

---

### 4. UI层 (Widgets)

#### `chat_screen.dart`（主屏幕）
```dart
class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 标签栏
          Consumer<TabManagerVM>(
            builder: (ctx, tabVM, _) {
              return TabBar(tabs);
            },
          ),
          // WebView容器
          Expanded(
            child: Consumer<TabManagerVM>(
              builder: (ctx, tabVM, _) {
                return WebViewContainer(tabVM.activeTab);
              },
            ),
          ),
          // 输入框
          InputArea(),
        ],
      ),
    );
  }
  
  AppBar _buildAppBar() {
    return AppBar(
      title: Text('AskMAI - Multi-LLM Chat'),
      actions: [
        IconButton(icon: Icon(Icons.add), onPressed: _showAddTabDialog),
      ],
    );
  }
}
```

#### `tab_bar.dart`（标签栏）
```dart
class TabBar extends StatelessWidget {
  final List<LLMTab> tabs;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<TabManagerVM>(
      builder: (ctx, tabVM, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.map((tab) {
              return GestureDetector(
                onTap: () => tabVM.switchTab(tab.id),
                child: _TabButton(
                  tab: tab,
                  isActive: tabVM.activeTabId == tab.id,
                  onClose: () => tabVM.removeTab(tab.id),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
```

#### `webview_container.dart`（WebView容器）
```dart
class WebViewContainer extends StatefulWidget {
  final LLMTab? tab;
  
  @override
  _WebViewContainerState createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  late WebViewController _controller;
  
  @override
  void initState() {
    super.initState();
    if (widget.tab != null) {
      _initializeWebView();
    }
  }
  
  void _initializeWebView() async {
    final tab = widget.tab!;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(tab.url));
    
    // 注册到WebViewService
    context.read<WebViewService>().addWebView(tab.id, _controller);
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.tab == null) {
      return Center(child: Text('No tab selected'));
    }
    return WebViewWidget(controller: _controller);
  }
}
```

#### `input_area.dart`（输入区）
```dart
class InputArea extends StatefulWidget {
  @override
  _InputAreaState createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  late TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }
  
  void _handleSend() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    
    _controller.clear();
    
    final distributorVM = context.read<InputDistributorVM>();
    await distributorVM.broadcastInput(message);
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter your question...',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(width: 8),
          Consumer<InputDistributorVM>(
            builder: (ctx, distributorVM, _) {
              return FloatingActionButton(
                onPressed: _handleSend,
                child: Icon(Icons.send),
                // 禁用状态下变灰
                backgroundColor: distributorVM.isSubmitting
                  ? Colors.grey
                  : Theme.of(context).primaryColor,
              );
            },
          ),
        ],
      ),
    );
  }
}
```

---

## 📦 依赖管理

### `pubspec.yaml`

```yaml
name: askmai
description: Multi-LLM Chat Client - Flutter

publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  
  # WebView & 自动化
  webview_flutter: ^4.0.0
  webview_flutter_android: ^5.0.0
  webview_flutter_wkwebview: ^5.0.0
  
  # 状态管理
  provider: ^6.0.0
  
  # 数据持久化
  shared_preferences: ^2.1.0
  
  # JSON序列化
  json_serializable: ^6.0.0
  json_annotation: ^4.8.0
  
  # 工具
  http: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  build_runner: ^2.4.0
  json_serializable: ^6.0.0

flutter:
  uses-material-design: true
  
  assets:
    - assets/site_config.json
```

---

## 🔄 数据流

### 场景：用户提交问题到所有标签页

```
1. 用户输入message在InputArea
   ↓
2. 点击Send按钮
   ↓
3. InputArea调用InputDistributorVM.broadcastInput(message)
   ↓
4. InputDistributorVM:
   - 获取所有活跃WebView (来自WebViewService)
   - 遍历每个tab
   - 对每个tab，AutomationVM.submitToTab()
   ↓
5. AutomationVM:
   - 查询tab的website config (来自SiteRegistry)
   - 调用JavascriptService.executeSubmit()
   - 注入固定JS函数 + 网站特定XPath
   ↓
6. JavascriptService:
   - 调用webViewController.runJavaScript()
   - JS在WebView上下文执行
   - 填充input、触发submit
   - 返回SubmissionResult
   ↓
7. InputDistributorVM收集所有结果
   - 更新_submissionStatus map
   - notifyListeners()
   ↓
8. UI通过Consumer<InputDistributorVM>获得更新
   - 显示加载指示符
   - 显示成功/失败反馈
   ↓
9. 最终状态通过Provider自动刷新到UI
```

---

## 🎯 关键设计原则

### 1. 复用性最大化
- **JS代码**：从Kotlin版本直接复用，无需修改
- **网站配置**：`site_config.json`无需改动
- **业务逻辑**：核心自动化逻辑完全保留

### 2. 关注点分离
- **Models**：数据定义，支持JSON序列化
- **Services**：底层实现细节（WebView、JS、存储）
- **ViewModels**：业务逻辑 + 状态管理
- **UI**：纯展示，通过Provider订阅状态

### 3. 并发安全
- 使用`Future.wait()`并发执行JS
- 每个tab的结果独立追踪
- 状态更新通过Provider原子化

### 4. 生命周期管理
- WebView实例在tab创建时初始化
- 在tab关闭时清理
- 应用暂停/恢复时管理JS执行

---

## ✅ 迁移检查清单

- [ ] Flutter项目脚手架创建
- [ ] 依赖安装与配置
- [ ] Models + JSON序列化代码生成
- [ ] Services层实现
- [ ] ViewModels层实现
- [ ] UI层实现
- [ ] Assets复制（site_config.json）
- [ ] Android/iOS特定配置
- [ ] 单元测试
- [ ] 集成测试
- [ ] 实机测试（Android + iOS）

---

## 📅 预期时间表

| 阶段 | 工作 | 预计时间 |
|-----|------|---------|
| 1 | 脚手架 + 依赖 | 1-2小时 |
| 2 | Models + Services | 3-4小时 |
| 3 | ViewModels | 2-3小时 |
| 4 | UI实现 | 4-5小时 |
| 5 | 集成 + 测试 | 3-4小时 |
| **总计** | | **13-18小时** |

---

## 🚀 后续行动

1. **用户审核**本设计文档
2. **确认无误**后，生成实现计划
3. **按阶段执行**项目构建

