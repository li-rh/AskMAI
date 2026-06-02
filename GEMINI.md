# AMAi - Project Instructions

This project is a multi-LLM chat client built with Flutter that allows users to send queries to multiple AI services simultaneously and compare their responses in a unified interface.

## Runtime Environment & Constraints (IMPORTANT)

- **Operating System**: Windows
- **Primary Shell**: PowerShell
- **Command Syntax**: Use PowerShell-compatible syntax for all shell commands.
  - **Chaining**: Do **NOT** use `&&`. Use `;` to chain commands (e.g., `cd askmai; flutter pub get`).
  - **Paths**: Use backslashes `\` or properly quoted forward slashes `/`.
  - **Avoid**: Avoid Linux-specific commands like `ls -la` (use `dir`), `grep` (use `Select-String`), or `cat` (use `Get-Content`).

## Project Overview

- **Core Functionality**: Concurrent querying of multiple LLM websites via WebViews and JavaScript/XPath automation.
- **Key Features**: Viewport customization (clipping/zooming), modern UI (Light/Dark mode), MVVM architecture, and extensible site configurations.
- **Target Platforms**: Android (Primary), iOS, Windows, Web.

## Development Environment & Commands

### Setup & Code Generation
```powershell
cd askmai; flutter pub get
# Generate JSON serialization code (required after modifying models)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running & Testing
- **Primary Target**: Physical Android device (`RMX3300`, ID: `be23d404`).
```powershell
# Run on physical phone
flutter run -d be23d404

# Analysis & Tests
flutter analyze; flutter test
```

## 📦 Project Structure (Flutter)

Use this map to quickly locate logic and avoid unnecessary file scanning:

```text
AskMAI/
├── askmai/                          # Main Flutter application directory
│   ├── lib/
│   │   ├── main.dart                # App Entry + Provider Tree Setup
│   │   ├── models/                  # Data structures (*.g.dart generated)
│   │   │   ├── llm_tab.dart         # Represents an active AI service tab
│   │   │   ├── site_config.dart     # XPath and viewport settings
│   │   │   └── submission_result.dart
│   │   ├── services/                # Business logic (Singletons)
│   │   │   ├── webview_service.dart # Manages WebViewController instances by tabId
│   │   │   ├── javascript_service.dart # Core JS injection orchestration
│   │   │   ├── site_registry.dart   # Loads assets/site_config.json
│   │   │   ├── preferences_service.dart
│   │   │   ├── app_config.dart          # Loads assets/app_config.json
│   │   │   ├── keyboard_visibility_manager.dart # Input focus protection
│   │   │   └── injection/           # JS Injection Strategies
│   │   │       ├── generic_strategy.dart    # Standard DOM XPath interaction
│   │   │       └── react_fiber_strategy.dart # Deep React Fiber/Slate.js bypass (e.g., Qwen)
│   │   ├── viewmodels/              # State management (ChangeNotifiers)
│   │   │   ├── tab_manager_vm.dart  # Manages the lifecycle of AI tabs
│   │   │   ├── automation_vm.dart   # The brain of parallel submission (Future.wait)
│   │   │   ├── input_distributor_vm.dart # Broadcasts user input to active tabs
│   │   │   └── app_settings_vm.dart # Theme and global preferences
│   │   ├── ui/                      # View Layer
│   │   │   ├── screens/
│   │   │   │   └── chat_screen.dart # Main layout scaffold
│   │   │   └── widgets/
│   │   │       ├── action_button_bar.dart
│   │   │       ├── desktop_web_viewer.dart
│   │   │       ├── input_area.dart  # The global bottom input field
│   │   │       ├── settings_bottom_sheet.dart  # DraggableScrollableSheet implementation
│   │   │       ├── tab_bar.dart     # Modern circular tab navigation
│   │   │       ├── viewport_adjust_dialog.dart # Site clipping UI
│   │   │       └── webview_container.dart      # Wrapper for WebView + Clipping Logic
│   │   └── utils/
│   │       ├── constants.dart
│   │       ├── extensions.dart
│   │       └── theme_config.dart    # Unified theme definitions
│   ├── assets/
│   │   ├── site_config.json         # Master configuration for XPath targets
│   │   └── app_config.json          # Global application default configurations
```

## 🔄 Data Flow (How queries are submitted)

If you need to debug a failure where text is not injecting into a website, trace this flow:
1. User types in `InputArea` -> clicks Send.
2. `InputDistributorVM.broadcastInput(message)` is called.
3. Iterates tabs via `AutomationVM.submitToAllTabs()`.
4. Executes concurrently: `Future.wait([jsService.executeSubmit(...)])`.
5. `JavascriptService` resolves the correct `InjectionStrategy` (Generic vs React Fiber).
6. Injects JS into WebView -> finds element via `XPath` -> sets value -> dispatches `input`/`change` events -> clicks submit.
7. `SubmissionResult` is gathered and `notifyListeners()` updates the UI.

## Operational Guidelines & Pitfalls (Crucial for AI)

To avoid common errors during implementation, strictly adhere to these guidelines:

### 1. State Management (Provider)
- **ChangeNotifier**: All ViewModels extend `ChangeNotifier`. You **MUST** call `notifyListeners()` after updating any internal state (e.g., in `finally` blocks of async methods) for the UI to reflect changes.
- **Consumers vs. Context**: Use `context.read<T>()` in event handlers (e.g., button presses) and `Consumer<T>` or `context.watch<T>()` in `build()` methods to minimize unnecessary rebuilds.

### 2. WebView & JavaScript Automation Constraints
- **Platform Limitations**: `WebViewWidget` is only fully functional on Android and iOS. For Web/Windows, a placeholder (`DesktopWebViewPlaceholder`) is rendered. **Do not attempt to execute JS injection on Windows/Web targets.**
- **React/SPA Sites**: Standard DOM manipulation (like setting `textarea.value`) often fails on sites built with React/Next.js (e.g., Qwen). Use or extend `ReactFiberStrategy` which bypasses DOM locks by directly accessing the React Fiber tree and Slate.js editor instances.
- **JSON Parsing**: The `runJavaScriptReturningResult` method behaves differently across platforms. Android often returns double-encoded JSON. Rely on `_parseResult` in `JavascriptService` to safely decode JS returns.

### 3. UI and Interaction Mapping
- **Focus Management**: The global input field (`InputArea`) needs to lose focus when a user interacts with the WebViews. Notice how `WebViewContainer` uses a `Listener` to detect pointer events and call `FocusManager.instance.primaryFocus?.unfocus()`. Maintain this pattern if creating new interactive overlays.
- **Viewport Clipping**: The app visually crops WebViews using `ClipRect`, `OverflowBox`, and `Transform.translate` within `WebViewContainer`. When debugging visual issues with specific LLM sites, check these offset values first.

## Development Conventions

1. **Services as Singletons**: All core services (e.g., `SiteRegistry`, `WebViewService`, `AppConfig`) use the singleton pattern.
2. **Exports Pattern**: Every directory has an `exports.dart`. Import via `import '.../exports.dart';` to keep imports clean.
3. **Initialization Order**: In `main.dart`, `PreferencesService`, `AppConfig`, and `SiteRegistry` must be initialized before `runApp()`.
4. **JSON Serialization**: Models use `@JsonSerializable()`. Rerun `build_runner` after any model change.
5. **XPath Interaction**: Target site structure via XPath defined in `assets/site_config.json`.
6. **Default Configurations**: Default theme, title bar, web load strategy, default enabled tabs, and GitHub links are defined in `assets/app_config.json`.

## AI Behavior & Interaction Rules

1. **Occam's Razor (奥卡姆剃刀法则)**: "如非必要，勿增实体" (Do not multiply entities beyond necessity). Keep solutions as simple as possible. Do not introduce new dependencies, redundant files, complex abstractions, or architectural layers unless strictly necessary to solve the problem at hand.
2. **Mandatory Sign-off**: At the very end of completing a user's task or directive, the AI MUST append the following exact phrase to its response:
   > "心态超好，注意休息"
