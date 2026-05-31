<div align="center">

# 🤖 AskMAI - 多模型APP (Ask Multi-AI)

[![Flutter](https://img.shields.io/badge/Flutter-3.8+-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-lightgrey.svg)]()

> 🚀 拒绝多应用切换，享受原生级问答体验！一键并发提问，自定义网页视口，轻松实现多个大模型回答的同屏对比。

[**下载体验**](#-快速开始与使用方式) · [**功能特性**](#-核心特性) · [**架构说明**](#-架构与实现原理) · [**已知问题**](#-目前已知问题) · [**后续规划**](#-后续待办事项-todo) · [**参与共建**](#-参与共建)

</div>

## 🖥️ 产品初衷与预览

市面上的很多聚合类 AI 软件仅仅是单纯的网页加载套壳，体验割裂。**AskMAI** 旨在为你提供**媲美原生的问答体验**。你不需要下载十几个不同的 AI App，也不需要为了对比各家模型的回答而来回复制粘贴同一个问题。在一个统一、现代化的界面中，AskMAI 帮你将问题一键分发，轻松实现多个 AI 大模型回答的同屏对比。

*(💡 提示：可以在这里放置项目的实际运行截图或演示 GIF)*

## ✨ 核心特性

| 特性 | 描述 |
|------|------|
| 🚀 **一键并发提问** | 在底部统一输入框输入问题，自动向所有已打开的 AI 标签页分发并提交，结果横向对比，一目了然。 |
| ✂️ **视口自定义裁剪** | **核心体验优化**：不同于普通的网页套壳，支持对加载的 AI 网页窗口进行精细的自定义缩放与视口裁剪。剔除多余的侧边栏、广告和导航，只保留最纯粹的对话界面。 |
| 🎨 **现代化 UI 设计** | 抛弃简陋的套壳感，采用现代化圆形设计语言与统一主题配色（支持浅色/深色模式），交互优雅，极具质感。 |
| 🛠️ **极强自定义扩展** | 内置管理面板，支持自定义添加各种 AI 大模型。只需通过配置目标网站的 `XPath` 路径（输入框与提交按钮），即可轻松接入新服务。 |
| 💾 **会话持久化** | 应用关闭后自动保存标签页状态，下次打开无缝衔接。 |
| 📦 **配置高效迁移** | 支持一键导出、导入所有自定义的 AI 模型配置，高效完成数据备份与跨设备间的无缝迁移。 |
| 🌍 **全平台制霸** | 采用 Flutter (MVVM + Provider) 构建，一套代码完美原生支持 Android、iOS、Windows 以及 Web 平台。 |

## 🚀 快速开始与使用方式

### 📦 方式一：直接下载安装 (推荐)

前往本仓库的 **Releases** 页面，下载对应操作系统的安装包即可直接安装体验。

### 🛠️ 方式二：从源码编译运行

**前置条件：**
- Flutter 3.0+ 和 Dart 3.0+ (推荐 3.8.0+)
- Android SDK 24+ (或 iOS 11+)

**编译步骤：**

```bash
# 1. 克隆项目到本地并进入目录
git clone https://github.com/your-username/AskMAI.git
cd AskMAI/askmai

# 2. 获取依赖包
flutter pub get

# 3. 生成 JSON 序列化等底层代码
# (修改 Models 后都需要运行此命令)
flutter pub run build_runner build
# 若遇到冲突报错，可执行：flutter pub run build_runner clean --delete-conflicting-outputs

# 4. 列出当前可用的设备
flutter devices

# 5. 编译并运行 (将 <device_id> 替换为你的目标设备，如 windows 或 android)
flutter run -d <device_id>
```

## 🧩 支持的 LLM 网站

配置文件 `assets/site_config.json` 中预定义了以下网站配置作为参考：

- **ChatGPT** (https://chat.openai.com)
- **Claude** (https://claude.ai)
- **Gemini** (https://gemini.google.com)
- **豆包** (https://www.doubao.com)
- **DeepSeek** (https://chat.deepseek.com)
- **千问** (https://www.qianwen.com)
- **Qwen** (https://chat.qwen.ai)
- **元宝** (https://yuanbao.tencent.com)

**如何配置新网站？**
编辑 `assets/site_config.json` 或直接在 App 内的设置中添加。使用浏览器开发者工具（F12）查找输入框和提交按钮的 XPath：
```json
{
  "sites": {
    "site_id": {
      "id": "site_id",
      "displayName": "Example LLM",
      "urlPattern": "https://example.com",
      "inputXPath": "//textarea[@id='input']",
      "submitXPath": "//button[@id='submit']",
      "isDisplay": true,
      "viewportTop": 0,
      "viewportBottom": 0,
      "viewportLeft": 0,
      "viewportRight": 0,
      "strategy": "generic"
    }
  }
}
```

## 🏗️ 架构与实现原理

本项目采用 **MVVM** 架构，使用 **Provider** 进行状态管理。核心逻辑基于 `webview_flutter` 与嵌入式的 **JavaScript 自动化引擎**：

### 目录结构

```text
lib/
├── main.dart                    # 应用入口
├── models/                      # 数据模型 (LLMTab, SiteConfig等)
├── services/                    # 业务服务层 (WebView, Javascript, Registry等)
├── viewmodels/                  # 状态管理层 (TabManager, Automation, Input等)
├── ui/                          # UI组件 (Screens, Widgets)
└── utils/                       # 工具类与主题配置
```

### 并发提交流程 (Data Flow)

1. **用户输入**: 用户在 InputArea 输入问题并点击 Send。
2. **统一广播**: `InputDistributorVM` 捕获输入并广播到所有活跃的 LLM Tab。
3. **并发注入**: `AutomationVM` 通过 `Future.wait` 并发调度 `JavascriptService`。
4. **执行 JS**: 每个 WebView 注入预设脚本，根据配置的 `XPath` 寻址、填入文本、触发 `input`/`change` 事件，并点击 `submit` 按钮。
5. **UI 反馈**: 收集所有 WebView 的 JSON 执行结果并通知 UI 更新状态。

## ⚠️ 目前已知问题

- **输入限制**：目前仅支持发送纯文本，暂不支持发送图片、文档等多模态文件内容。

## 📝 后续待办事项 (TODO)

- [ ] **注入引擎升级**：支持多种更底层的文本注入方式与事件模拟（例如 React/Vue 特殊事件劫持）。
- [ ] **多模态支持**：支持图片/文件的拖拽上传与识别。
- [ ] **内置浏览器闭环**：支持在软件内部以标准浏览器形态打开 AI 回答中的网页外链。
- [ ] **桌面端开发**：增加更丰富的全局快捷键支持与系统托盘能力。
- [ ] **自动化测试**：完善核心业务逻辑的单元测试覆盖。

## 常见问题 (FAQ)

**Q: 为什么某些网站 JS 注入失败？**
A: 可能原因包括：XPath 表达式不正确、网站更新了 HTML DOM 结构，或者网站本身有特殊的 JS 事件拦截/防护机制。

**Q: 如何调试 WebView？**
A: 可以在 `WebViewContainer` 的 `initState` 中添加 `debugPrintBeginFrame = true;` 开启调试日志，或使用对应平台的 WebView 开发者工具调试。

## 🤝 参与共建

> **“个人能力有限，基本纯靠 Vibe Coding 进行开发，希望大家可以积极提出 issue 和参与开发，让这个项目更加完善！”**

非常欢迎各位开发者参与到 AskMAI 的建设中来！不论是提交反馈，还是直接参与代码贡献，我们都非常感激：
- 🐛 **提交 Bug**：发现任何注入失败的网页或 UI 错位，欢迎提交 Issue。
- 💡 **分享配置**：如果你调配出了好用的某个 AI 站点的最佳 XPath 和视口缩放比例，欢迎分享。
- 🛠️ **提交 PR**：如果你有能力解决 `TODO` 列表中的问题，欢迎直接提交 Pull Request！

## 📄 License

本项目采用 [MIT License](LICENSE) 协议开源，你可以自由地使用、修改和分发。

---
**版本**: 1.0.0 | **构建日期**: 2026-05-29