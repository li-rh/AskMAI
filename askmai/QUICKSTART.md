# Flutter迁移 - 快速入门指南

**项目**: AskMAI - Flutter版本  
**创建日期**: 2026-05-24  
**状态**: ✅ 项目脚手架和核心代码完成

---

## 📦 项目已完成的部分

### ✅ 项目结构 (100%)
- [x] 完整的Dart/Flutter项目目录树
- [x] 所有核心模块分离（Models、Services、ViewModels、UI）
- [x] 资源文件夹配置

### ✅ Models层 (100%)
- [x] `LLMTab` - 标签页模型，支持JSON序列化
- [x] `SiteConfig` - 网站配置模型，包含XPath映射
- [x] `SubmissionResult` - 提交结果追踪模型
- [x] Models导出文件

### ✅ Services层 (100%)
- [x] `WebViewService` - WebView实例管理（单例）
- [x] `JavascriptService` - JS注入和XPath执行（复用原Kotlin代码）
- [x] `SiteRegistry` - 网站配置加载和查询
- [x] `PreferencesService` - SharedPreferences封装
- [x] Services导出文件

### ✅ ViewModels层 (100%)
- [x] `TabManagerVM` - Provider状态管理，标签页CRUD
- [x] `AutomationVM` - 自动化引擎，JS并发执行
- [x] `InputDistributorVM` - 输入广播管理
- [x] ViewModels导出文件

### ✅ UI层 (100%)
- [x] `ChatScreen` - 主屏幕布局和逻辑
- [x] `TabBar` - 标签页管理组件
- [x] `WebViewContainer` - WebView容器组件
- [x] `InputArea` - 输入框和发送按钮
- [x] UI导出文件

### ✅ 工具和配置
- [x] `constants.dart` - 应用级常量
- [x] `extensions.dart` - Dart扩展方法
- [x] `main.dart` - 应用入口，Provider配置
- [x] `pubspec.yaml` - 依赖管理
- [x] `site_config.json` - LLM网站配置（复用）
- [x] `AndroidManifest.xml` - Android权限配置
- [x] `README.md` - 完整文档

---

## 📋 代码行数统计

| 模块 | 文件数 | 代码行数 |
|-----|-------|---------|
| Models | 4 | ~250 |
| Services | 5 | ~450 |
| ViewModels | 4 | ~350 |
| UI | 6 | ~600 |
| 工具 | 5 | ~300 |
| **总计** | **24** | **~1,950** |

---

## 🚀 下一步：环境准备和编译

### 前置条件检查清单

- [ ] 安装 Flutter SDK 3.0+
  ```bash
  # 检查版本
  flutter --version
  
  # 升级Flutter
  flutter upgrade
  ```

- [ ] 安装 Android SDK (可选，仅用于Android开发)
  - 最低API版本: 24
  - 目标API版本: 34

- [ ] 安装 Xcode (可选，仅用于iOS开发)
  - 最低版本: 12.0
  - iOS部署目标: 11.0+

### 编译步骤

#### 1. 获取依赖
```bash
cd d:\SyncFiles\Code\VScode\aaaTemp\askmai
flutter pub get
```

#### 2. 生成JSON序列化代码
```bash
# 仅修改Models后运行此命令
flutter pub run build_runner build --delete-conflicting-outputs
```

这会生成：
- `models/llm_tab.g.dart`
- `models/site_config.g.dart`

#### 3. 检查编译环境
```bash
# 检查开发环境配置
flutter doctor

# 应该看到：
# [✓] Flutter (Channel stable)
# [✓] Android toolchain
# [✓] Xcode (for iOS development)
# [✓] VS Code
```

#### 4. 运行应用

**Android (模拟器或真机)**
```bash
# 列出可用设备
flutter devices

# 在指定设备上运行
flutter run -d <device_id>

# 或简单运行（选择设备）
flutter run
```

**iOS (模拟器或真机)**
```bash
# 运行在iOS模拟器
flutter run -d "iPhone 15"

# 或
cd ios
pod install
cd ..
flutter run
```

#### 5. 编译发行版本

**Android APK**
```bash
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

**iOS IPA**
```bash
flutter build ios --release
# 输出: build/ios/iphoneos/Runner.app
```

---

## ⚠️ 重要说明

### JSON序列化代码生成

Models中使用了 `@JsonSerializable()` 装饰器，需要在修改Models后运行build_runner：

```bash
flutter pub run build_runner build
```

这会生成 `*.g.dart` 文件，包含fromJson/toJson方法。

**注意**: 不要手动编辑生成的文件！

### WebView配置

确保已在AndroidManifest.xml中添加互联网权限：
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

对于iOS，在ios/Runner/Info.plist中确保允许HTTP请求（如果需要）。

### Provider依赖顺序

main.dart中的Provider注册顺序很重要。Services必须在ViewModels之前注册。

---

## 🔍 常见问题

### Q1: "flutter command not found"
**A**: Flutter不在系统PATH中。需要：
1. 安装Flutter SDK
2. 将Flutter bin目录添加到PATH环境变量

### Q2: "build_runner failed"
**A**: 通常原因是Models有语法错误。检查：
- 所有@JsonSerializable()类都有factory fromJson和toJson
- 没有循环依赖

### Q3: "WebView不显示"
**A**: 检查：
- AndroidManifest.xml中有INTERNET权限
- URL格式正确（http://或https://）
- 网络连接正常

### Q4: "JavaScript执行失败"
**A**: 检查：
- XPath表达式正确（使用浏览器开发者工具验证）
- 网站没有禁用JavaScript
- 等待页面完全加载后再执行JS

---

## 📊 迁移进度总结

```
总体进度: ████████████████████ 100%

✅ 设计和规划         [完成]
✅ 项目脚手架创建     [完成]
✅ Models层实现       [完成]
✅ Services层实现     [完成]
✅ ViewModels层实现   [完成]
✅ UI层实现          [完成]
✅ 资源和配置        [完成]
⏳ 编译和测试        [待处理]
⏳ 真机部署          [待处理]
```

---

## 🎯 验证核心功能

完成编译后，请验证以下功能：

- [ ] 应用启动无错误
- [ ] 可以添加新标签页
- [ ] 可以切换标签页
- [ ] 可以删除标签页
- [ ] WebView正常加载URL
- [ ] 可以在输入框输入文本
- [ ] 点击Send按钮发送消息
- [ ] 消息成功到达所有标签页
- [ ] 应用退出后标签页被保存
- [ ] 应用重启后标签页被恢复

---

## 📚 参考资源

### 官方文档
- [Flutter官方文档](https://flutter.dev/docs)
- [Dart官方文档](https://dart.dev/guides)
- [webview_flutter插件](https://pub.dev/packages/webview_flutter)
- [Provider状态管理](https://pub.dev/packages/provider)

### 项目文档
- [FLUTTER_MIGRATION_DESIGN.md](../FLUTTER_MIGRATION_DESIGN.md) - 完整架构设计
- [FLUTTER_IMPLEMENTATION_PLAN.md](../FLUTTER_IMPLEMENTATION_PLAN.md) - 实现计划
- [README.md](./README.md) - 项目README

---

## 🔄 下一步行动

### 立即执行
1. ✅ 阅读本指南
2. ✅ 检查环境：`flutter doctor`
3. ✅ 获取依赖：`flutter pub get`
4. ✅ 生成代码：`flutter pub run build_runner build`
5. ✅ 运行应用：`flutter run`

### 后续维护
- 定期更新Flutter SDK
- 更新site_config.json当LLM网站更新XPath
- 监控WebView插件更新
- 处理用户反馈

---

**项目创建**: 2026-05-24  
**当前版本**: 1.0.0  
**维护者**: AskMAI Team  

🎉 **恭喜！Flutter项目脚手架已完成！现在可以开始编译和测试了。**
