# Quick Start Guide / 快速开始指南

## English

### Prerequisites
1. **JDK 17+** - Download from [Oracle](https://www.oracle.com/java/technologies/downloads/) or [OpenJDK](https://adoptopenjdk.net/)
2. **Android SDK** - Install via [Android Studio](https://developer.android.com/studio)
3. **Set Environment Variables**:
   - `JAVA_HOME` → JDK installation directory
   - `ANDROID_HOME` → Android SDK directory

### Quick Setup
```bash
# 1. Check environment
.\check-env.bat          # Windows
bash check-env.sh        # Linux/macOS

# 2. Sync dependencies (auto-downloads everything)
.\gradlew.bat sync       # Windows
./gradlew sync           # Linux/macOS

# 3. Build debug APK
.\gradlew.bat assembleDebug

# 4. Install on device/emulator
.\gradlew.bat installDebug

# 5. Run app
.\gradlew.bat runDebug
```

### Open in Android Studio
1. Launch Android Studio
2. File → Open Project
3. Select AskMAI project root
4. Wait for Gradle sync
5. Click Run (Shift+F10)

---

## 中文

### 前置要求
1. **JDK 17+** - 从 [Oracle](https://www.oracle.com/java/technologies/downloads/) 或 [OpenJDK](https://adoptopenjdk.net/) 下载
2. **Android SDK** - 通过 [Android Studio](https://developer.android.com/studio) 安装
3. **设置环境变量**:
   - `JAVA_HOME` → JDK 安装目录
   - `ANDROID_HOME` → Android SDK 目录

### 快速设置
```powershell
# 1. 检查环境 (Windows)
.\check-env.bat

# 2. 同步依赖 (自动下载所有依赖)
.\gradlew.bat sync

# 3. 构建 Debug APK
.\gradlew.bat assembleDebug

# 4. 安装到设备/模拟器
.\gradlew.bat installDebug

# 5. 运行应用
.\gradlew.bat runDebug
```

### 使用 Android Studio 打开
1. 启动 Android Studio
2. File → Open Project
3. 选择 AskMAI 项目根目录
4. 等待 Gradle 同步完成
5. 点击 Run (Shift+F10)

### 环境变量设置 (PowerShell)
```powershell
# 设置 JAVA_HOME
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"

# 设置 ANDROID_HOME
$env:ANDROID_HOME = "C:\Users\$env:USERNAME\AppData\Local\Android\sdk"

# 持久化设置 (添加到 PowerShell 配置文件)
Add-Content -Path $PROFILE -Value '$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"'
Add-Content -Path $PROFILE -Value '$env:ANDROID_HOME = "C:\Users\$env:USERNAME\AppData\Local\Android\sdk"'
```

---

## Troubleshooting / 故障排除

| Issue | Solution |
|-------|----------|
| `java: command not found` | 设置 JAVA_HOME 和 PATH |
| `ANDROID_HOME is not set` | 设置 ANDROID_HOME 环境变量 |
| `Gradle sync failed` | 运行 `.\gradlew.bat clean` 然后重试 |
| `No connected devices` | 检查 ADB: `adb devices` |

---

For detailed setup instructions, see [SETUP.md](./SETUP.md)

详细设置说明请查看 [SETUP.md](./SETUP.md)
