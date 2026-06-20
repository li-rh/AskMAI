# AMAi - Multi-LLM Chat Client (Developer & Agent Guide)

This document is the single source of truth for all developer agents (including Claude Code, Gemini, and other LLMs) working on the **AMAi** repository. It contains environment-specific guidelines, architecture details, development commands, operational conventions, and rules.

---

## 🚀 Project Status & Tech Stack

- **Status**: Core Implementation & UI Modernization Complete ✅✅✅
- **Last Updated**: 2026-06-04
- **Current Phase**: Polish, UI/UX Refinement & Cross-Platform Extension
- **Architecture**: MVVM + Provider (State Management)
- **Target Platforms**: Android (Primary Target), iOS, Windows (Desktop), Web
- **Core Purpose**: Concurrent querying of multiple LLM websites via WebViews and JavaScript/XPath automation.

---

## 💻 Developer Tool Environments

Different developer agent CLI tools run in different environments. Please strictly adhere to your tool's environment constraints:

### 1. Claude Code Environment (Bash)
- **Operating System**: Windows 11 Pro for Workstations
- **Primary Shell**: `bash` (Git Bash / MSYS2)
- **Command Syntax**: Use standard Unix-style/bash syntax. Chaining with `&&` or `||` is fully supported.
- **Paths**: Use forward slashes (e.g., `D:/SyncFiles/Code/VScode/aaaTemp/AskMAI/...`).
- **ADB Path**: `C:\Users\RyanLi\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- **Windows Caveats under Bash**: Use `flutter.bat` or `flutter` directly. `/dev/null` is mapped to `NUL` automatically by the shell runtime.

### 2. Gemini / Antigravity Environment (PowerShell)
- **Operating System**: Windows
- **Primary Shell**: PowerShell
- **Command Syntax**: Use PowerShell-compatible syntax.
  - **Chaining**: Do **NOT** use `&&`. Use `;` to chain commands (e.g., `cd askmai; flutter pub get`).
  - **Paths**: Use backslashes `\` or properly quoted forward slashes `/`.
  - **Command Names**: Avoid Linux-specific commands like `ls -la` (use `dir`), `grep` (use `Select-String`), or `cat` (use `Get-Content`).

---

## 📱 Targets & Connected Devices

Always deploy, test, and debug on the **primary physical Android target**. Do not attempt to run Web or Windows desktop platforms for testing WebView/JS interactions.

| Device ID | Name | Platform | Target Priority |
| :--- | :--- | :--- | :--- |
| `be23d404` | RMX3300 | Android 15 (Physical Phone) | **Primary Target** (Always test here) |
| `emulator-5554` | gphone16k | Android 17 (Emulator) | Secondary Target |
| `windows` | Windows | Desktop | Skip (WebView placeholder only) |
| `edge` | Edge | Web | Skip (WebView placeholder only) |

---

## 🔧 Setup & Build Commands

Depending on your shell, execute commands as formatted below:

### Setup & Code Generation
- **Bash (Claude)**:
  ```bash
  cd askmai
  flutter pub get
  flutter pub run build_runner build --delete-conflicting-outputs
  ```
- **PowerShell (Gemini/Antigravity)**:
  ```powershell
  cd askmai; flutter pub get
  flutter pub run build_runner build --delete-conflicting-outputs
  ```

### Running the App
- **Bash (Claude)**:
  ```bash
  # Run on primary phone (with hot-reload enabled)
  flutter run -d be23d404 --hot
  ```
- **PowerShell (Gemini/Antigravity)**:
  ```powershell
  # Run on primary phone
  flutter run -d be23d404
  ```
*Note: In the running Flutter console, press `r` to trigger **Hot Reload** (apply code changes without losing state), or `R` (Shift+R) to trigger **Hot Restart**.*

### Analysis & Testing
- **Bash (Claude)**:
  ```bash
  flutter analyze
  flutter test
  flutter doctor
  ```
- **PowerShell (Gemini/Antigravity)**:
  ```powershell
  flutter analyze; flutter test
  ```

### Release Building
```bash
# Android APK
flutter build apk --release
# iOS IPA
flutter build ios --release
# Web
flutter build web
```

---

## 📦 Project Structure (Flutter)

All Flutter code is located in the `askmai/` subdirectory. Use this layout to locate components:

```text
AskMAI/
├── askmai/                          # Flutter application root
│   ├── lib/
│   │   ├── main.dart                # Entry point + MultiProvider setup
│   │   ├── models/                  # Data structures (with build_runner generated .g.dart)
│   │   │   ├── llm_tab.dart         # Active AI tab representation
│   │   │   ├── site_config.dart     # XPath and viewport configurations
│   │   │   └── submission_result.dart # JS execution results
│   │   ├── services/                # Singleton Business Services
│   │   │   ├── webview_service.dart # Manages WebViewController mapping by tabId
│   │   │   ├── javascript_service.dart # JS Injection orchestration
│   │   │   ├── site_registry.dart   # Loads site_config.json
│   │   │   ├── preferences_service.dart # SharedPreferences wrapper
│   │   │   ├── app_config.dart      # Global settings manager (loads app_config.json)
│   │   │   ├── keyboard_visibility_manager.dart # Focus & keyboard management
│   │   │   └── injection/           # Javascript injection strategies
│   │   │       ├── generic_strategy.dart # Standard DOM XPath interaction
│   │   │       └── text_filler.dart          # 各策略 Filler（dom_input, exec_command, react_slate 等）
│   │   ├── viewmodels/              # State Management / ChangeNotifier ViewModels
│   │   │   ├── tab_manager_vm.dart  # Handles tab CRUD & persistence
│   │   │   ├── automation_vm.dart   # Future.wait concurrency coordinator
│   │   │   ├── input_distributor_vm.dart # Captures and broadcasts user inputs
│   │   │   └── app_settings_vm.dart # Theme and global settings VM
│   │   ├── ui/                      # View Layer
│   │   │   ├── screens/
│   │   │   │   └── chat_screen.dart # Main screen Scaffold
│   │   │   └── widgets/
│   │   │       ├── action_button_bar.dart # Top-left viewport adjustment controls
│   │   │       ├── desktop_web_viewer.dart # Fallback for unsupported platforms
│   │   │       ├── input_area.dart  # Global question input area
│   │   │       ├── settings_bottom_sheet.dart # Draggable scrollable settings drawer
│   │   │       ├── tab_bar.dart     # Modern circular tab navigation bar
│   │   │       ├── viewport_adjust_dialog.dart # Web clip / zoom dialog
│   │   │       └── webview_container.dart # Interactive WebView + visual cropping clip
│   │   └── utils/
│   │       ├── constants.dart       # Asset paths and defaults
│   │       ├── extensions.dart      # Color and state helpers
│   │       └── theme_config.dart    # Circle design, fonts & visual theme configs
│   ├── assets/
│   │   ├── site_config.json         # XPath rules & selectors for each AI site
│   │   └── app_config.json          # Global app default configurations (loaded at start)
```

---

## 🎨 MVVM Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         ChatScreen (UI)                         │
│             Reads and watches ViewModels via Provider           │
├─────────────────────────────────────────────────────────────────┤
│              Provider (MultiProvider tree in main.dart)         │
├─────────────────────────────────────────────────────────────────┤
│  ViewModels (ChangeNotifier)  │     Services (Singleton)        │
│  ├── TabManagerVM             │     ├── WebViewService         │
│  ├── AutomationVM             │     ├── JavascriptService      │
│  └── InputDistributorVM       │     ├── SiteRegistry           │
│                               │     └── PreferencesService     │
├─────────────────────────────────────────────────────────────────┤
│                         Models                                  │
│  ├── LLMTab                   │     SiteConfig                 │
│  └── SubmissionResult         │                                │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow (Submitting a Query)

1. User enters message in `InputArea` → clicks Send button.
2. `InputDistributorVM.broadcastInput(message)` captures the input text.
3. `AutomationVM.submitToAllTabs()` is triggered.
4. Concurrent submission executes across all active tabs via `Future.wait`:
   ```dart
   Future.wait([
     jsService.executeSubmit(tab1, ...),
     jsService.executeSubmit(tab2, ...),
   ])
   ```
5. `JavascriptService` resolves the strategy (`GenericStrategy` vs `ReactSlateFiller`) and runs:
   - Evaluates target XPath in site WebView.
   - Sets input field value and dispatches `input` + `change` events.
   - Dispatches `click` on the submit button.
6. Submissions complete, returning a `SubmissionResult` JSON.
7. `InputDistributorVM` aggregates results & updates submission statuses.
8. ViewModels call `notifyListeners()`, triggering consumer rebuilds in UI.

---

## ⚡ JavaScript Injection & XPath Automation

### Standard XPath Injection
For standard HTML forms, the app injects a single, reusable JavaScript function to locate input and click submit:
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

### React / SPA Interception
Modern Single Page Applications (e.g. Qwen, ChatGPT) lock input values and ignore plain DOM modifications. The app employs `ReactSlateFiller` to directly target react fiber keys, locate underlying slate/textarea state, bypass synthetic events, and set values securely.

---

## ⚙️ Core Configuration Files

### 1. Site Selectors (`askmai/assets/site_config.json`)
Contains configurations and XPath queries to identify inputs/buttons:
```json
{
  "sites": {
    "chatgpt": {
      "urlPattern": "^https://chatgpt\\.com",
      "inputXPath": "//div[@id='prompt-textarea']",
      "submitXPath": "//button[@data-testid='send-button']",
      "displayName": "ChatGPT"
    }
  }
}
```
*To add a site: Append a configuration under the `"sites"` key and configure standard browser XPath selectors.*

### 2. Application Defaults (`askmai/assets/app_config.json`)
Stores app default themes and active tabs configuration, loaded during startup by `AppConfig`:
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

---

## 🛠️ Operational Guidelines & Pitfalls (CRITICAL)

When modifying codebase logic, strictly follow these requirements:

### 1. State Management (Provider)
- **Notify Listeners**: ViewModels extend `ChangeNotifier`. Call `notifyListeners()` after updating internal state (typically in `finally` blocks of async routines) to ensure the UI updates.
- **Context Optimization**:
  - Use `context.read<T>()` in event listeners and callbacks (e.g. button presses) to avoid unnecessary rebuilds.
  - Use `Consumer<T>` or `context.watch<T>()` within `build()` methods where UI components need to react to state changes.

### 2. Platform Constraints & JSON Encoding
- **Windows / Web Limits**: `WebViewWidget` is only supported on Android/iOS. When running on Desktop/Web, the placeholder `DesktopWebViewPlaceholder` is used. **Do not attempt running JS injections on Windows/Web.**
- **JSON Parsing**: The WebView execution result returned by `runJavaScriptReturningResult` on Android is often double-JSON-encoded. Always use the built-in parser in `JavascriptService._parseResult` to unpack values cleanly.

### 3. Viewport & UX Alignment
- **Focus Release**: When interacting with the WebView, the keyboard must not obstruct the frame. `WebViewContainer` uses a custom `Listener` to detect touch interactions and unfocus the input area via `FocusManager.instance.primaryFocus?.unfocus()`. Preserve this UX layout.
- **Viewport Clipping**: WebViews are custom cropped and zoomed using combinations of `ClipRect`, `OverflowBox`, and `Transform.translate` inside `WebViewContainer`. Review these translation attributes if a site renders incorrectly.
- **Initialization Order**: Inside `main.dart`, services must load in sequence:
  1. `PreferencesService.init()`
  2. `AppConfig.loadConfig()`
  3. `SiteRegistry.loadConfigs()`
  4. `runApp()`

### 4. General Conventions
- **Singletons**: Core services are implemented as singletons.
- **Clean Imports**: Code layers contain an `exports.dart` file. Import using folder exports rather than individual file paths.
- **JSON Generation**: Run `build_runner` after editing any serializable `@JsonSerializable()` model files.

### 5. Common Issues
- **XPath Outdated**: LLM websites frequently change their HTML. Update `inputXPath`/`submitXPath` in `site_config.json`.
- **WebView Not Loading**: Ensure `JavaScriptMode.unrestricted` is set in `WebViewContainer`.

---

## 🤖 AI Behavior & Interaction Rules

1. **Occam's Razor (奥卡姆剃刀法则)**: "如非必要，勿增实体" (Do not multiply entities beyond necessity). Keep codebase clean, simple, and avoid adding unneeded packages, structures, files, or extra layers of abstraction.
2. **Mandatory Sign-off**: All developer AI agents (including Claude and Gemini) MUST append the following phrase at the very end of their response when they finish a task:
   > "心态超好，注意休息"
