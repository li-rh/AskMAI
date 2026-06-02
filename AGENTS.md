# AMAi - Multi-LLM Chat Client

## 🚀 Project Status

- **Status**: Core Implementation & UI Modernization Complete ✅✅✅
- **Build System**: Flutter / Dart
- **Architecture**: MVVM + Provider
- **Last Updated**: 2026-05-29
- **Current Phase**: Polish, UI/UX Refinement & Cross-Platform Extension

## Project Overview

**AMAi** is a cross-platform application built with Flutter that enables users to send queries simultaneously to multiple Large Language Models (LLMs) and view their responses side-by-side through a tabbed interface. It functions like a browser with multiple LLM tabs, allowing users to quickly compare and switch between different AI responses.

### Core Purpose
- 📱 Send a single question to multiple LLM services simultaneously
- 🔄 Switch between LLM conversation tabs seamlessly
- ⚙️ Execute JavaScript to automate input and submission across tabs
- 🎯 Provide a unified, intuitive interface for comparing LLM outputs
- 🌍 Support Mobile (Android/iOS), Desktop (Windows), and Web platforms from a single codebase
- 🎨 Modern, circular design with unified theme configuration
- 🪟 Viewport adjustment for fine-grained web content control

---

## 🆕 Recent Updates (May 2026)

- **UI Modernization**: Implemented a circular design system and unified theme configuration (`theme_config.dart`).
- **Settings & Dialogs**: Overhauled the settings panel to use a `DraggableScrollableSheet` with proper height constraints and drag-to-close behavior, and fixed edit AI tab dialog overlap issues.
- **Viewport Control**: Added dynamic viewport adjustments (`viewport_adjust_dialog.dart`) and temporary disable functionality to control window display content. Control buttons were also relocated to the left layout.
- **Input & Focus Management**: Resolved issues with keyboard focus being automatically cancelled when scrolling web pages (`keyboard_visibility_manager`).
- **Cross-Platform Footprint**: Expanded directory structure to officially support Web and Windows platforms alongside Mobile.

---

## Tech Stack

- **Language**: Dart 3.8.0+ (primary)
- **Framework**: Flutter (Material Design 3)
- **Target Platforms**: Android, iOS, Windows, Web
- **Architecture**: MVVM (Model-View-ViewModel) pattern
- **State Management**: Provider 6.0.0 (ChangeNotifier pattern)
- **WebView**: webview_flutter 4.0.0 for displaying LLM websites
- **JavaScript Bridge**: Embedded JavaScript execution via WebViewController
- **Async**: Dart async/await with Future for concurrent operations
- **Local Data**: SharedPreferences 2.1.0 for tab URLs and settings
- **JSON Serialization**: json_serializable 6.0.0 & json_annotation 4.8.0 (code generation)
- **Other Utilities**: url_launcher 6.2.0, uuid 4.0.0, http 1.1.0

---

## 📦 Project Structure (Flutter)

```text
AskMAI/
├── askmai/                          # Flutter应用主目录
│   ├── lib/
│   │   ├── main.dart                # 应用入口 + Provider配置
│   │   ├── models/                  # 数据模型
│   │   │   ├── llm_tab.dart
│   │   │   ├── site_config.dart
│   │   │   └── submission_result.dart
│   │   ├── services/                # 业务逻辑与系统服务
│   │   │   ├── webview_service.dart
│   │   │   ├── javascript_service.dart
│   │   │   ├── site_registry.dart
│   │   │   ├── preferences_service.dart
│   │   │   ├── app_config.dart          # 全局应用配置加载服务
│   │   │   └── keyboard_visibility_manager.dart # 焦点与键盘可见性管理
│   │   ├── viewmodels/              # 状态管理
│   │   │   ├── tab_manager_vm.dart
│   │   │   ├── automation_vm.dart
│   │   │   └── input_distributor_vm.dart
│   │   ├── ui/                      # 视图层
│   │   │   ├── screens/
│   │   │   │   └── chat_screen.dart
│   │   │   └── widgets/
│   │   │       ├── action_button_bar.dart
│   │   │       ├── desktop_web_viewer.dart
│   │   │       ├── input_area.dart
│   │   │       ├── settings_bottom_sheet.dart  # DraggableScrollableSheet实现
│   │   │       ├── tab_bar.dart
│   │   │       ├── viewport_adjust_dialog.dart # 视口控制
│   │   │       └── webview_container.dart
│   │   └── utils/
│   │       ├── constants.dart
│   │       ├── extensions.dart
│   │       └── theme_config.dart    # 统一主题样式
│   ├── assets/
│   │   ├── site_config.json         # LLM网站XPath配置
│   │   └── app_config.json          # 全局应用默认配置（主题、标题栏、默认开启Tab、GitHub等）
│   ├── android/                     # Android原生工程配置
│   ├── ios/                         # iOS原生工程配置
│   ├── windows/                     # Windows原生工程配置
│   ├── web/                         # Web工程配置
│   ├── pubspec.yaml                 # 依赖管理
│   ├── README.md
│   └── QUICKSTART.md
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

#### SiteRegistry & Preferences
- 从assets/site_config.json加载LLM网站配置
- SharedPreferences的便捷封装，持久化活跃标签和URLs

### 3. **ViewModels Layer** (State Management with Provider)

#### TabManagerVM (ChangeNotifier)
- 标签页生命周期管理：增删改查、活跃切换和持久化

#### AutomationVM & InputDistributorVM
- 自动化引擎：JS执行和并发XPath应用 (Future.wait)
- 捕获用户输入，广播到所有打开的LLM Tab
- 追踪每个标签页的提交状态反馈

### 4. **UI Layer** (Flutter Widgets)

#### Layout & Controls
- **ChatScreen**: 主屏幕布局（Scaffold框架集成输入与显示）。
- **SettingsBottomSheet**: 高度动态调整的抽屉，限制屏幕2/3最大高度。
- **ViewportAdjustDialog**: 调整视图窗口内容的缩放与适配。

#### Display Components
- **TabBar Widget**: 水平滚动列表，处理标签的新增/关闭与高亮。
- **WebViewContainer**: WebViewWidget包装（进度条、错误状态展示）。
- **InputArea**: TextField与发送按钮的封装。

---

## 🔄 Data Flow

### 用户提交问题的流程

```text
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
      ...
    ])
   ↓
6. 每个tab的WebView注入并执行JS：
   - 寻找XPath目标元素 → 填充input值 → 触发事件 → 点击submit → 返回JSON
   ↓
7. InputDistributorVM收集所有结果
   - 更新_submissionStatus Map
   - notifyListeners() → UI更新
   ↓
8. UI通过Consumer更新状态反馈
```

---

## 🔧 Build & Run Commands

### 获取依赖
```bash
flutter pub get
```

### 生成JSON序列化代码
```bash
flutter pub run build_runner build
# 如果遇到冲突：
flutter pub run build_runner clean --delete-conflicting-outputs
```

### 开发运行
```bash
# 列出可用设备 (Web, Windows, Mobile)
flutter devices

# 指定设备运行
flutter run -d <device_id>
```

---

## JavaScript + XPath Implementation

### Fixed JavaScript Function
The app injects a single, reusable JavaScript function into all WebViews. It dynamically locates DOM elements from XPath configurations:

```javascript
function submitForm(inputXPath, submitXPath, messageText) {
  try {
    const inputElement = document.evaluate(
      inputXPath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null
    ).singleNodeValue;
    
    const submitButton = document.evaluate(
      submitXPath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null
    ).singleNodeValue;
    
    if (!inputElement || !submitButton) {
      return JSON.stringify({ success: false, error: 'Elements not found' });
    }
    
    inputElement.value = messageText;
    inputElement.dispatchEvent(new Event('input', { bubbles: true }));
    inputElement.dispatchEvent(new Event('change', { bubbles: true }));
    
    submitButton.click();
    return JSON.stringify({ success: true, timestamp: Date.now() });
  } catch (e) {
    return JSON.stringify({ success: false, error: e.message });
  }
}
```

---

## Global Application Configuration

The default application configuration (e.g. default theme, show/hide app bar, default web load strategy, default enabled tabs, and GitHub repository URL) is stored in `askmai/assets/app_config.json` and loaded at startup via the `AppConfig` service:

```json
{
  "themeMode": "auto",
  "showAppBar": false,
  "webLoadStrategy": "sequential",
  "defaultEnabledTabs": [
    "ChatGPT",
    "豆包",
    "DeepSeek",
    "千问",
    "元宝"
  ],
  "githubUrl": "https://github.com/li-rh/AskMAI"
}
```

This file serves as a single source of truth for the app's default settings and metadata, making it easy to modify defaults in the future.

---

## 🔗 Quick Links

- **Project Directory**: `D:\SyncFiles\Code\VScode\aaaTemp\AskMAI\`
- **Flutter App**: `askmai/`
- **Design Doc**: `FLUTTER_MIGRATION_DESIGN.md`
- **Impl Plan**: `FLUTTER_IMPLEMENTATION_PLAN.md`

*Configuration updated on: 2026-06-01*
