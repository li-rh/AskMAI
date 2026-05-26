# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Runtime Environment

- **OS**: Windows 11 Pro for Workstations
- **Shell**: bash (Git Bash / MSYS2), Unix-style syntax
- **Paths**: Use forward slashes (e.g., `D:/SyncFiles/...`), not backslashes
- **Windows caveats**: `&&` and `||` work, but avoid Linux-only commands (e.g., `apt`, `systemctl`). Use `flutter.bat` or just `flutter` directly. `/dev/null` maps to `NUL` automatically by the shell runtime — just use `/dev/null` as normal.
- **Terminal**: All shell commands run in bash on Windows. Do not use PowerShell or CMD syntax.
- **ADB**: C:\Users\RyanLi\AppData\Local\Android\Sdk\platform-tools\adb.exe
---

AskMAI is a Flutter multi-LLM chat client that sends queries simultaneously to multiple LLM services (ChatGPT, Claude, Gemini, Doubao) and displays their responses in a tabbed interface. It uses WebViews with JavaScript/XPath automation to interact with LLM websites.

**Tech Stack**: Flutter 3.0+ / Dart 3.0+, Provider (state management), webview_flutter, MVVM architecture

---

## Development Commands

### Environment Setup
```bash
cd askmai

# Get dependencies
flutter pub get

# Generate JSON serialization code (required after modifying models)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running the App

**IMPORTANT**: Always deploy and test on the connected physical Android phone (`RMX3300`), NOT on web or Windows desktop.

```bash
# List available devices
flutter devices

# Run on the physical phone (primary target)
flutter run -d be23d404

# Hot reload (apply code changes without losing state)
# Press 'r' in the running Flutter terminal

# Hot restart (restart app, reset state)
# Press 'R' (Shift+R) in the running Flutter terminal

# Or run with hot-reload enabled from the start (default)
flutter run -d be23d404 --hot
```

**Connected devices**:
| Device ID   | Name       | Platform      |
|-------------|------------|---------------|
| be23d404    | RMX3300    | Android 15 (physical phone) |
| emulator-5554 | gphone16k | Android 17 (emulator) |
| windows     | Windows    | desktop (skip) |
| edge        | Edge       | web (skip) |

### Building
```bash
# Android APK
flutter build apk --release

# iOS IPA
flutter build ios --release

# Web
flutter build web
```

### Analysis & Testing
```bash
flutter analyze
flutter test
flutter doctor
```

---

## Architecture

### MVVM + Provider Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                         ChatScreen (UI)                         │
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

1. User enters message in `InputArea` → clicks Send
2. `InputDistributorVM.broadcastInput()` captures input
3. `AutomationVM.submitToAllTabs()` iterates all tabs
4. JavaScript injected via `WebViewController.runJavaScript()`:
   ```javascript
   submitForm(inputXPath, submitXPath, messageText)
   ```
5. JS uses XPath to locate elements, fills input, clicks submit
6. Results returned via `SubmissionResult`, UI updates via `notifyListeners()`

---

## Key Design Decisions

### WebView + JavaScript Automation
- No API keys needed - interacts directly with LLM websites
- Fixed JS function with dynamic XPath per site (defined in `assets/site_config.json`)
- XPath patterns must be updated when LLM sites change their HTML structure

### Provider + ChangeNotifier
- `Provider<T>.value()` for services (singletons)
- `ChangeNotifierProvider` for ViewModels (observable state)
- UI uses `Consumer<T>` and `context.read<T>()` to access state

### Concurrent Submissions
- `Future.wait()` executes all tab submissions in parallel
- Each `WebViewController` operates independently

---

## Important Conventions

### Services Are Singletons
All services use singleton pattern:
```dart
static final SiteRegistry _instance = SiteRegistry._internal();
factory SiteRegistry() => _instance;
```

### Models Use JSON Serialization
- Annotate with `@JsonSerializable()`
- Rerun `build_runner` after modifying models
- Generated files (*.g.dart) are in `.dart_tool/build/`

### Exports Pattern
Each layer has `exports.dart` for clean imports:
```dart
export 'model_a.dart';
export 'model_b.dart';
// Then import: import 'models/exports.dart';
```

### Service Initialization Order
In `main.dart`, services must initialize sequentially:
1. `PreferencesService.init()`
2. `SiteRegistry.loadConfigs()`
3. Then `runApp()` → Provider setup

---

## File Organization

```
askmai/lib/
├── main.dart                          # App entry + MultiProvider
├── models/                            # Data structures
│   ├── llm_tab.dart                   # Tab state
│   ├── site_config.dart               # XPath config per site
│   └── submission_result.dart         # JS execution result
├── services/                          # Business logic
│   ├── webview_service.dart           # Map<tabId, WebViewController>
│   ├── javascript_service.dart        # JS injection + XPath
│   ├── site_registry.dart             # site_config.json loader
│   └── preferences_service.dart       # SharedPreferences wrapper
├── viewmodels/                        # Observable state
│   ├── tab_manager_vm.dart            # Tab lifecycle
│   ├── automation_vm.dart             # JS execution orchestrator
│   └── input_distributor_vm.dart      # Input broadcast
├── ui/
│   ├── screens/chat_screen.dart       # Main screen
│   └── widgets/                       # Reusable components
│       ├── tab_bar.dart
│       ├── webview_container.dart
│       └── input_area.dart
└── utils/
    ├── constants.dart                 # App constants
    └── extensions.dart                # Dart extensions

askmai/assets/
└── site_config.json                   # LLM site XPath configurations
```

---

## Adding a New LLM Site

1. Edit `askmai/assets/site_config.json`:
```json
{
  "sites": {
    "newllm": {
      "urlPattern": "^https://newllm\\.com",
      "inputXPath": "//textarea[@id='input']",
      "submitXPath": "//button[@type='submit']",
      "displayName": "New LLM"
    }
  }
}
```

2. Use browser DevTools to find correct XPath expressions for the input field and submit button.

3. Restart the app - configuration loads at startup.

---

## Common Issues

- **XPath outdated**: LLM websites frequently change their HTML. Update `inputXPath`/`submitXPath` in `site_config.json`.
- **WebView not loading**: Ensure `JavaScriptMode.unrestricted` is set in `WebViewContainer`.
- **State not updates**: Remember to call `notifyListeners()` in ViewModel methods.