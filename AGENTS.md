# AskMAI - Multi-LLM Chat Client

## 🚀 Project Status

- **Status**: Flutter Core Implementation Complete ✅✅✅
- **Build System**: Flutter / Dart
- **Architecture**: MVVM + Provider
- **Last Updated**: 2026-05-24
- **Next Phase**: Compilation, Testing & Deployment

## Project Overview

**AskMAI** is a cross-platform mobile application built with Flutter that enables users to send queries simultaneously to multiple Large Language Models (LLMs) and view their responses side-by-side through a tabbed interface. It functions like a browser with multiple LLM tabs, allowing users to quickly compare and switch between different AI responses.

### Core Purpose
- 📱 Send a single question to multiple LLM services simultaneously
- 🔄 Switch between LLM conversation tabs seamlessly
- ⚙️ Execute JavaScript to automate input and submission across tabs
- 🎯 Provide a unified, intuitive interface for comparing LLM outputs
- 🌍 Support both Android and iOS with a single codebase

---

## Tech Stack

- **Language**: Dart 3.0+ (primary)
- **Framework**: Flutter 3.0+
- **Target Platforms**: Android 5.0+ (API 24) & iOS 11.0+
- **Architecture**: MVVM (Model-View-ViewModel) pattern
- **State Management**: Provider 6.0.0 (ChangeNotifier pattern)
- **UI Framework**: Flutter Material Design 3
- **WebView**: webview_flutter 4.0.0 for displaying LLM websites
- **JavaScript Bridge**: Embedded JavaScript execution via WebViewController
- **Async**: Dart async/await with Future for concurrent operations
- **Local Data**: SharedPreferences 2.1.0 for tab URLs and settings
- **JSON Serialization**: json_serializable 6.0.0 (code generation)
- **DI**: Manual singleton pattern + Provider

---

## 📦 Project Structure (Flutter)

```
AskMAI/
├── askmai/                          # Flutter应用主目录
│   ├── lib/
│   │   ├── main.dart                # 应用入口 + Provider配置
│   │   ├── models/
│   │   │   ├── llm_tab.dart        # 标签页数据模型
│   │   │   ├── site_config.dart    # LLM网站配置模型
│   │   │   └── submission_result.dart
│   │   ├── services/
│   │   │   ├── webview_service.dart      # WebView实例管理
│   │   │   ├── javascript_service.dart   # JS注入和执行
│   │   │   ├── site_registry.dart        # 网站配置加载
│   │   │   └── preferences_service.dart  # SharedPreferences封装
│   │   ├── viewmodels/
│   │   │   ├── tab_manager_vm.dart       # 标签页生命周期
│   │   │   ├── automation_vm.dart        # 自动化引擎
│   │   │   └── input_distributor_vm.dart # 输入分发
│   │   ├── ui/
│   │   │   ├── screens/
│   │   │   │   └── chat_screen.dart      # 主屏幕
│   │   │   └── widgets/
│   │   │       ├── tab_bar.dart
│   │   │       ├── webview_container.dart
│   │   │       └── input_area.dart
│   │   └── utils/
│   │       ├── constants.dart
│   │       └── extensions.dart
│   ├── assets/
│   │   └── site_config.json          # LLM网站XPath配置
│   ├── android/
│   │   └── app/src/main/
│   │       └── AndroidManifest.xml   # 权限和配置
│   ├── ios/
│   │   └── Runner/                   # iOS项目配置
│   ├── pubspec.yaml                  # 依赖管理
│   ├── README.md
│   └── QUICKSTART.md
│
├── FLUTTER_MIGRATION_DESIGN.md       # 完整架构设计文档
├── FLUTTER_IMPLEMENTATION_PLAN.md    # 实现计划
├── FLUTTER_MIGRATION_SUMMARY.md      # 迁移完成总结
├── README-SETUP.md
├── INDEX.md
└── AGENTS.md                         # 本文件
```

---

## Architecture & Core Components

### 1. **Models Layer** (Data Models)
- **LLMTab**: 代表一个LLM标签页（包含ID、URL、名称、WebViewController）
- **SiteConfig**: 存储LLM网站的XPath配置（输入字段、提交按钮）
- **SubmissionResult**: 记录JavaScript执行结果（成功/失败状态）

### 2. **Services Layer** (Business Logic)

#### WebViewService
- 单例模式，管理多个WebViewController实例
- Map<tabId, WebViewController>存储映射
- 提供add/get/remove/getAllWebViews方法

#### JavascriptService
- 注入固定的JavaScript函数到WebView
- 使用XPath表达式定位DOM元素
- 自动填充表单和触发提交
- 返回JSON格式的执行结果
- **特点**: JS代码100%复用Kotlin版本

#### SiteRegistry
- 从assets/site_config.json加载LLM网站配置
- 支持URL正则表达式匹配
- 提供快速的配置查询

#### PreferencesService
- SharedPreferences的便捷封装
- 保存/恢复标签页URLs
- 记忆活跃标签页

### 3. **ViewModels Layer** (State Management with Provider)

#### TabManagerVM (ChangeNotifier)
- 标签页生命周期管理：增删改查
- 活跃标签页切换
- 标签页持久化和恢复
- 供UI通过Provider订阅

#### AutomationVM (ChangeNotifier)
- 自动化引擎：JS执行和XPath应用
- submitToTab()单个提交
- submitToAllTabs()并发提交
- Future.wait()并发控制

#### InputDistributorVM (ChangeNotifier)
- 捕获用户输入
- 向所有标签页广播消息
- 追踪每个标签页的提交状态
- 提供统计方法（成功/失败计数）

### 4. **UI Layer** (Flutter Widgets)

#### ChatScreen
- 主屏幕布局：Scaffold框架
- 集成标签栏、WebView容器、输入框
- 显示提交状态反馈
- 提供添加标签页对话框

#### TabBar Widget
- 水平滚动的标签页列表
- 活跃标签高亮（底线）
- 标签页切换和关闭按钮
- 添加新标签页按钮

#### WebViewContainer
- WebViewWidget包装
- 页面加载进度条
- 错误处理和显示
- 空状态提示

#### InputArea
- TextField输入框
- FloatingActionButton发送按钮
- 加载状态动画
- 输入验证和反馈

### 5. **Utilities**
- **constants.dart**: 应用级常量、错误/成功消息
- **extensions.dart**: String、List、DateTime等Dart扩展方法

---

## 🔄 Data Flow

### 用户提交问题的流程

```
1. 用户在InputArea输入消息
   ↓
2. 点击Send按钮
   ↓
3. InputDistributorVM.broadcastInput(message)
   ↓
4. AutomationVM.submitToAllTabs()
   ↓
5. [并发执行] Future.wait([
      jsService.executeSubmit(tab1, ...),
      jsService.executeSubmit(tab2, ...),
      jsService.executeSubmit(tab3, ...),
      ...
    ])
   ↓
6. 每个tab的WebView：
   - 调用runJavaScript()注入固定JS函数
   - JS使用XPath定位input和submit按钮
   - 填充input值
   - 点击submit按钮
   - 返回JSON结果
   ↓
7. InputDistributorVM收集所有结果
   - 更新_submissionStatus Map
   - notifyListeners() → UI更新
   ↓
8. UI通过Consumer订阅状态变化
   - 显示成功/失败反馈
   - 更新加载指示器
```

---

## 🎯 Key Design Decisions

### 1. WebView + JavaScript自动化
- **为什么**: 无需API密钥，支持任何网站
- **如何**: 固定JS框架 + 动态XPath配置
- **好处**: 灵活性最大，易于扩展新网站

### 2. Provider + MVVM
- **为什么**: 响应式状态管理，UI自动更新
- **如何**: ChangeNotifier + Consumer/Provider
- **好处**: 关注点分离，易于测试

### 3. 并发执行
- **为什么**: 同时向所有LLM发送请求
- **如何**: Future.wait()并发执行
- **好处**: 响应快速，用户体验好

### 4. SharedPreferences持久化
- **为什么**: 应用重启后恢复标签页
- **如何**: 保存/恢复tabs列表
- **好处**: 无缝用户体验

---

## 📋 Development Conventions

### Naming Conventions
- **Dart文件**: snake_case (e.g., `tab_manager_vm.dart`)
- **类名**: PascalCase (e.g., `TabManagerVM`, `LLMTab`)
- **变量/方法**: camelCase (e.g., `activeTabId`, `addTab()`)
- **常量**: camelCase或UPPER_CASE (e.g., `appName`, `MAX_TABS`)

### Code Organization
- 每个类职责单一
- Services层处理业务逻辑
- ViewModels层处理状态管理
- UI层仅处理展示逻辑
- 使用export.dart统一导出

### Code Quality
- **类型安全**: 充分使用Dart类型系统
- **Null安全**: 使用? 和 ! 运算符，避免NPE
- **异常处理**: try-catch包装所有异步操作
- **日志记录**: 使用print()或自定义Logger
- **代码注释**: 文档注释(///)用于公共API

---

## 🔧 Build & Run Commands

### 获取依赖
```bash
flutter pub get
```

### 生成JSON序列化代码
```bash
flutter pub run build_runner build
```

### 清除生成的文件
```bash
flutter pub run build_runner clean --delete-conflicting-outputs
```

### 开发运行
```bash
# 在连接的设备/模拟器上运行
flutter run

# 指定设备
flutter run -d <device_id>

# 列出可用设备
flutter devices
```

### 编译Release版本
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS IPA
flutter build ios --release
```

### 诊断
```bash
# 检查开发环境
flutter doctor

# 检查依赖
flutter pub outdated
```

---

## Development Conventions

### Naming Conventions
- **Dart files**: snake_case (e.g., `tab_manager_vm.dart`, `llm_tab.dart`)
- **Classes**: PascalCase (e.g., `TabManagerVM`, `LLMTab`)
- **Variables/Methods**: camelCase (e.g., `activeTabId`, `addTab()`)
- **Constants**: UPPER_SNAKE_CASE or camelCase

### Package Structure (lib/)
```
lib/
├── main.dart                        # App entry + Provider setup
├── models/                          # Data models
│   ├── llm_tab.dart
│   ├── site_config.dart
│   ├── submission_result.dart
│   └── exports.dart
├── services/                        # Business logic
│   ├── webview_service.dart
│   ├── javascript_service.dart
│   ├── site_registry.dart
│   ├── preferences_service.dart
│   └── exports.dart
├── viewmodels/                      # State management
│   ├── tab_manager_vm.dart
│   ├── automation_vm.dart
│   ├── input_distributor_vm.dart
│   └── exports.dart
├── ui/
│   ├── screens/
│   │   ├── chat_screen.dart
│   │   └── exports.dart
│   └── widgets/
│       ├── tab_bar.dart
│       ├── webview_container.dart
│       ├── input_area.dart
│       └── exports.dart
└── utils/
    ├── constants.dart
    ├── extensions.dart
    └── exports.dart
```

### Code Quality Standards
- **Null Safety**: Use ? for nullable types, ! only when certain
- **Error Handling**: Try-catch for all async operations
- **Comments**: Doc comments (///) for public APIs
- **Testing**: Unit tests for services, widget tests for UI
- **Logging**: Use print() for debug, consider Logger package for production

---

## 🔑 Core Technologies

### Flutter & Dart
- **Dart 3.0+**: Strong static typing, null safety
- **Flutter 3.0+**: Cross-platform UI framework
- **Null Safety**: Modern Dart null handling

### State Management (Provider)
- **Provider 6.0.0**: Service locator + state management
- **ChangeNotifier**: Observable pattern for ViewModels
- **Consumer**: Subscribe to state changes in widgets

### WebView Integration
- **webview_flutter 4.0.0**: Cross-platform WebView
- **runJavaScript()**: Execute JS in web context
- **NavigationDelegate**: Handle page load events

### JSON & Serialization
- **json_serializable**: Code generation for fromJson/toJson
- **@JsonSerializable()**: Annotation for auto-generation
- **build_runner**: Code generation tool

### Async & Concurrency
- **Future**: Single async value
- **Stream**: Multiple async values
- **async/await**: Readable async code
- **Future.wait()**: Concurrent operations

---

## JavaScript + XPath Implementation

### Fixed JavaScript Function (Reused from Kotlin)
The app injects a single, reusable JavaScript function into all WebViews:

```javascript
function submitForm(inputXPath, submitXPath, messageText) {
  try {
    // Locate input using XPath
    const inputElement = document.evaluate(
      inputXPath, document, null,
      XPathResult.FIRST_ORDERED_NODE_TYPE, null
    ).singleNodeValue;
    
    // Locate submit button using XPath
    const submitButton = document.evaluate(
      submitXPath, document, null,
      XPathResult.FIRST_ORDERED_NODE_TYPE, null
    ).singleNodeValue;
    
    if (!inputElement || !submitButton) {
      return JSON.stringify({ success: false, error: 'Elements not found' });
    }
    
    // Fill input field
    inputElement.value = messageText;
    inputElement.dispatchEvent(new Event('input', { bubbles: true }));
    inputElement.dispatchEvent(new Event('change', { bubbles: true }));
    
    // Click submit button
    submitButton.click();
    
    return JSON.stringify({ success: true, timestamp: Date.now() });
  } catch (e) {
    return JSON.stringify({ success: false, error: e.message });
  }
}
```

### XPath Configuration
Each LLM site requires XPath patterns stored in `assets/site_config.json`:

```json
{
  "sites": {
    "chatgpt": {
      "urlPattern": "^https://chat\\.openai\\.com",
      "inputXPath": "//textarea[@placeholder='Message ChatGPT']",
      "submitXPath": "//button[@data-testid='send-button']",
      "displayName": "ChatGPT"
    },
    "claude": {
      "urlPattern": "^https://claude\\.ai",
      "inputXPath": "//textarea[@placeholder='Message Claude']",
      "submitXPath": "//button[contains(@aria-label, 'Send')]",
      "displayName": "Claude"
    }
  }
}
```

### Runtime Execution Flow
1. User enters query → InputArea captures text
2. Send button triggered → InputDistributorVM.broadcastInput()
3. AutomationVM iterates through all tabs
4. For each tab: JavascriptService.executeSubmit()
5. JS executes: runJavaScript() → submitForm(inputXPath, submitXPath, message)
6. JS locates elements via XPath, fills input, clicks submit
7. Result captured and returned to Flutter
8. UI updated with success/failure status

---

## 🎯 Important Patterns & Best Practices

### Single Responsibility Principle
- **Models**: Data structure only
- **Services**: Business logic, external communication
- **ViewModels**: State management, orchestration
- **UI**: Display and user interaction only

### Error Handling
```dart
try {
  final result = await someAsyncOperation();
  return result;
} catch (e) {
  print('Error: $e');
  return SubmissionResult(
    success: false,
    error: e.toString(),
    timestamp: DateTime.now(),
    tabId: tabId,
  );
}
```

### Concurrent Operations
```dart
// Execute all submissions in parallel
final results = await Future.wait([
  automationVM.submitToTab(tab1.id, message, tab1),
  automationVM.submitToTab(tab2.id, message, tab2),
  automationVM.submitToTab(tab3.id, message, tab3),
]);
```

### State Management with Provider
```dart
// In widget
Consumer<TabManagerVM>(
  builder: (context, tabVM, _) {
    return ListView(
      children: tabVM.tabs.map((tab) => Text(tab.displayName)).toList(),
    );
  },
)
```

### WebView Management
- Always call addWebView() to register controller
- Never dispose controller manually (WebView manages it)
- Enable JavaScriptMode.unrestricted for automation
- Handle page load events with NavigationDelegate

---

## ⚠️ Common Pitfalls to Avoid

1. **Blocking UI Thread**: Never do heavy work in UI thread → Use async/await
2. **JS Injection Errors**: Always escape special characters in XPath/strings
3. **XPath Changes**: Monitor LLM websites for HTML structure changes
4. **Memory Leaks**: Properly dispose StreamControllers and subscriptions
5. **Race Conditions**: Use Future.wait() for parallel operations
6. **Lost Tab State**: Always persist tabs to SharedPreferences
7. **Unsandboxed JS**: Never execute user-provided JS → Always use fixed functions

---

## 🧪 Testing Strategy

### Unit Tests (Services)
- Test WebViewService methods
- Test SiteRegistry URL matching
- Test PreferencesService serialization
- Test ViewModel logic

### Widget Tests (UI)
- Test TabBar interaction
- Test InputArea validation
- Test ChatScreen layout

### Integration Tests
- Test complete user flow: add tab → input message → receive response

---

## 📚 Documentation Files

1. **FLUTTER_MIGRATION_DESIGN.md** (190 lines)
   - Complete architecture design
   - Component descriptions
   - Data flow diagrams
   
2. **FLUTTER_IMPLEMENTATION_PLAN.md** (220 lines)
   - Step-by-step implementation guide
   - File-by-file breakdown
   - Time estimates
   
3. **FLUTTER_MIGRATION_SUMMARY.md** (long)
   - Project completion summary
   - Code statistics
   - Quality metrics

4. **askmai/README.md** (180 lines)
   - Project overview
   - Feature list
   - Installation guide
   - FAQ

5. **askmai/QUICKSTART.md** (220 lines)
   - Quick start guide
   - Environment setup
   - Build commands
   - Troubleshooting

---

## 🚀 Quick Start

### 1. Environment Setup
```bash
# Install Flutter (if not already)
flutter pub global activate fvm
fvm install 3.10.0 (or latest stable)

# Clone/enter project
cd askmai

# Get dependencies
flutter pub get

# Generate code
flutter pub run build_runner build
```

### 2. Run Application
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Or run on default device
flutter run
```

### 3. Build Release
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## 🛠️ Project Configuration & Setup

### Environment Setup Completed ✅

The following has been configured and is ready to use:

**Build System**:
- ✅ Flutter SDK 3.0+
- ✅ Dart 3.0+ compiler
- ✅ Pub package manager

**Flutter Configuration**:
- ✅ Target SDK: Android API 24+, iOS 11.0+
- ✅ Material Design 3 UI
- ✅ Null safety enabled

**Dependencies**:
- ✅ webview_flutter 4.0.0
- ✅ provider 6.0.0
- ✅ shared_preferences 2.1.0
- ✅ json_serializable 6.0.0
- ✅ uuid 4.0.0
- ✅ http 1.1.0

**Project Structure**:
- ✅ Dart source directory: `lib/`
- ✅ Resources: `assets/`
- ✅ Android: `android/`
- ✅ iOS: `ios/`
- ✅ Build configuration: `pubspec.yaml`

---

## 📁 File Structure Reference

```
AskMAI/
├── askmai/                          # Flutter application
│   ├── lib/
│   │   ├── main.dart               # Application entry point
│   │   ├── models/
│   │   ├── services/
│   │   ├── viewmodels/
│   │   ├── ui/
│   │   └── utils/
│   ├── assets/
│   │   └── site_config.json        # LLM site configurations
│   ├── android/
│   │   └── app/src/main/
│   │       └── AndroidManifest.xml # Android configuration
│   ├── ios/
│   │   └── Runner/                 # iOS configuration
│   ├── pubspec.yaml                # Dependency management
│   ├── README.md
│   └── QUICKSTART.md
│
├── FLUTTER_MIGRATION_DESIGN.md
├── FLUTTER_IMPLEMENTATION_PLAN.md
├── FLUTTER_MIGRATION_SUMMARY.md
├── AGENTS.md                       # This file
├── README-SETUP.md
├── INDEX.md
└── CONFIG-REPORT.md
```

---

## 🔗 Quick Links

- **Project Directory**: `d:\SyncFiles\Code\VScode\aaaTemp\AskMAI\`
- **Flutter App**: `askmai/`
- **Design Doc**: `FLUTTER_MIGRATION_DESIGN.md`
- **Impl Plan**: `FLUTTER_IMPLEMENTATION_PLAN.md`
- **Summary**: `FLUTTER_MIGRATION_SUMMARY.md`

---

*Configuration completed on: 2026-05-24*  
*For latest updates, see individual documentation files.*
