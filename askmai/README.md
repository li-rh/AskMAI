# AskMAI - Flutter Multi-LLM Chat Client

一个Flutter应用，用于同时向多个大型语言模型(LLM)发送查询，并通过标签页界面比较它们的响应。

## 特性

- 🌐 **多标签页支持** - 像浏览器一样管理多个LLM标签页
- 🚀 **并发提交** - 同时向所有LLM发送相同的问题
- ⚙️ **自动化** - 使用JavaScript和XPath自动填充和提交表单
- 📱 **跨平台** - 支持Android和iOS
- 💾 **会话持久化** - 应用关闭后自动保存标签页

## 技术栈

- **语言**: Dart/Flutter
- **架构**: MVVM + Provider (状态管理)
- **WebView**: webview_flutter
- **本地存储**: shared_preferences
- **自动化**: JavaScript + XPath

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/                      # 数据模型
│   ├── llm_tab.dart
│   ├── site_config.dart
│   └── submission_result.dart
├── services/                    # 业务服务层
│   ├── webview_service.dart
│   ├── javascript_service.dart
│   ├── site_registry.dart
│   └── preferences_service.dart
├── viewmodels/                  # 状态管理层
│   ├── tab_manager_vm.dart
│   ├── automation_vm.dart
│   └── input_distributor_vm.dart
├── ui/
│   ├── screens/
│   │   └── chat_screen.dart
│   └── widgets/
│       ├── tab_bar.dart
│       ├── webview_container.dart
│       └── input_area.dart
└── utils/
    ├── constants.dart
    └── extensions.dart

assets/
├── site_config.json             # LLM网站XPath配置
```

## 快速开始

### 前置条件

- Flutter 3.0+ 和 Dart 3.0+
- Android SDK 24+ (或 iOS 11+)

### 安装

1. 克隆项目
```bash
cd askmai
```

2. 获取依赖
```bash
flutter pub get
```

3. 生成JSON序列化代码
```bash
flutter pub run build_runner build
```

4. 运行应用
```bash
# Android
flutter run

# iOS
flutter run -d "iPhone 15"
```

## 使用指南

### 添加新标签页

1. 点击标签栏右侧的 **+** 按钮
2. 输入LLM网站URL和显示名称
3. 点击 **Add** 确认

### 发送问题

1. 在底部输入框输入你的问题
2. 按 **Send** 按钮或按Enter键
3. 问题会同时发送到所有活跃标签页

### 管理标签页

- **切换标签页**: 点击标签页标题
- **关闭标签页**: 点击标签页右侧的 ✕ 按钮

## 支持的LLM网站

配置文件 `assets/site_config.json` 中预定义了以下网站:

- ChatGPT (https://chat.openai.com)
- Claude (https://claude.ai)
- Google Gemini (https://gemini.google.com)
- Doubao (https://www.doubao.com)

你可以编辑配置文件以添加更多网站或自定义现有的XPath表达式。

## 架构说明

### Models (数据模型)
- `LLMTab`: 代表一个标签页
- `SiteConfig`: 存储网站的XPath配置
- `SubmissionResult`: 记录JavaScript执行结果

### Services (服务层)
- `WebViewService`: 管理多个WebView实例
- `JavascriptService`: 执行JavaScript注入和XPath定位
- `SiteRegistry`: 加载和查询网站配置
- `PreferencesService`: 管理本地存储

### ViewModels (状态管理)
- `TabManagerVM`: 标签页生命周期管理
- `AutomationVM`: 自动化引擎和JS执行
- `InputDistributorVM`: 输入广播和提交管理

### UI (用户界面)
- `ChatScreen`: 主屏幕
- `TabBar`: 标签栏组件
- `WebViewContainer`: WebView容器
- `InputArea`: 输入框和发送按钮

## 并发提交流程

```
User Input
    ↓
InputDistributorVM.broadcastInput()
    ↓
AutomationVM.submitToAllTabs()
    ↓
[并发执行] Future.wait([
    jsService.executeSubmit(tab1),
    jsService.executeSubmit(tab2),
    jsService.executeSubmit(tab3),
    ...
])
    ↓
SubmissionResult集合
    ↓
UI更新显示成功/失败状态
```

## 文件说明

### pubspec.yaml
- 依赖管理
- 资源配置 (assets/site_config.json)

### site_config.json
```json
{
  "sites": {
    "siteName": {
      "urlPattern": "^https://example\\.com",
      "inputXPath": "//textarea[@id='input']",
      "submitXPath": "//button[@id='submit']",
      "displayName": "Example LLM"
    }
  }
}
```

## 常见问题

### Q: 如何添加新的LLM网站?
A: 编辑 `assets/site_config.json`，添加新的网站条目。使用浏览器开发者工具查找输入字段和提交按钮的XPath。

### Q: 为什么JS注入失败?
A: 可能原因：
- XPath表达式不正确
- 网站更新了HTML结构
- 网站有特殊的JS防护机制

### Q: 如何调试WebView问题?
A: 在 `WebViewContainer` 中启用调试日志：
```dart
// 在initState中添加
debugPrintBeginFrame = true;
```

## 开发指南

### 生成JSON序列化代码
修改Models后，运行：
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 本地测试
```bash
# 在Android模拟器上运行
flutter run -d emulator-5554

# 在连接的真机上运行
flutter run
```

### 编译Release版本
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 许可证

MIT License

## 贡献

欢迎提交Issues和Pull Requests！

---

**最后更新**: 2026-05-24
**版本**: 1.0.0
