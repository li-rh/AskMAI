import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/theme_config.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';
import '../widgets/exports.dart';
import '../widgets/viewport_adjust_dialog.dart';

/// 主聊天屏幕
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  DateTime? _lastBackPressTime;
  OverlayEntry? _toastOverlayEntry;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastOverlayEntry?.remove();
    _toastOverlayEntry = null;
    super.dispose();
  }

  void _showExitToast() {
    _toastTimer?.cancel();
    if (_toastOverlayEntry != null) {
      _toastOverlayEntry!.remove();
      _toastOverlayEntry = null;
    }

    _toastOverlayEntry = OverlayEntry(
      builder: (context) => const Positioned(
        bottom: 140,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.center,
          child: ToastBubble(
            message: '再返回一次退出',
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_toastOverlayEntry!);

    _toastTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_toastOverlayEntry != null) {
        _toastOverlayEntry!.remove();
        _toastOverlayEntry = null;
      }
    });
  }

  void _handleBackPress() {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(milliseconds: 1500)) {
      _lastBackPressTime = now;
      _showExitToast();
    } else {
      _toastTimer?.cancel();
      if (_toastOverlayEntry != null) {
        _toastOverlayEntry!.remove();
        _toastOverlayEntry = null;
      }
      SystemNavigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();

    // 应用启动时恢复标签页，ViewModel内部会处理初始化默认标签页
    Future.microtask(() async {
      final tabVM = context.read<TabManagerVM>();
      await tabVM.restoreTabs();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保系统状态栏始终显示
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  void _showAddTabDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    final inputXPathController = TextEditingController();
    final submitXPathController = TextEditingController();
    bool isEnabled = true;
    bool isDisplayed = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Tab'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        hintText: 'https://chat.openai.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        hintText: 'ChatGPT',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: inputXPathController,
                      decoration: const InputDecoration(
                        labelText: 'Input XPath (Optional)',
                        hintText: '//textarea[@placeholder="..."]',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: submitXPathController,
                      decoration: const InputDecoration(
                        labelText: 'Submit Button XPath (Optional)',
                        hintText: '//button[@id="send"]',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: isEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    isEnabled = value ?? true;
                                  });
                                },
                              ),
                              const Text('Enabled'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: isDisplayed,
                                onChanged: (value) {
                                  setState(() {
                                    isDisplayed = value ?? true;
                                  });
                                },
                              ),
                              const Text('Display'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final url = urlController.text.trim();
                    final name = nameController.text.trim();

                    if (url.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in URL and Display Name'),
                        ),
                      );
                      return;
                    }

                    // 验证URL格式
                    if (!url.startsWith('http://') &&
                        !url.startsWith('https://')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'URL must start with http:// or https://',
                          ),
                        ),
                      );
                      return;
                    }

                    context.read<TabManagerVM>().addTab(
                      url,
                      name,
                      customInputXPath: inputXPathController.text.trim().isEmpty
                          ? null
                          : inputXPathController.text.trim(),
                      customSubmitXPath:
                          submitXPathController.text.trim().isEmpty
                              ? null
                              : submitXPathController.text.trim(),
                      isEnabled: isEnabled,
                      isDisplayed: isDisplayed,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onRefreshTab(String tabId) {
    context.read<WebViewService>().reloadWebView(tabId);
  }

  /// 新建对话 - 重置所有tabs的URL为默认值，并重新加载
  Future<void> _handleNewChat() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建对话'),
          content: const Text('是否要重置所有标签页并开始新对话？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final tabVM = context.read<TabManagerVM>();
    final webViewService = context.read<WebViewService>();
    final siteRegistry = SiteRegistry();

    // 重置所有tabs的URL为默认值
    for (int i = 0; i < tabVM.tabs.length; i++) {
      final tab = tabVM.tabs[i];
      
      // 尝试通过URL找回原始的配置
      final config = siteRegistry.getConfigByUrl(tab.url);
      String defaultUrl = tab.url; // 默认回退为当前URL

      if (config != null) {
        defaultUrl = config.urlPattern;
      }

      // 更新tab的URL
      final updatedTab = tab.copyWith(url: defaultUrl);
      tabVM.updateTab(updatedTab);

      // 使用新URL加载WebView（而非仅刷新）
      webViewService.navigateWebView(tab.id, defaultUrl);
    }

    // 保存更新
    await tabVM.persistTabs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已开始新对话'), duration: Duration(seconds: 2)),
      );
    }
  }

  /// 打开设置界面
  void _handleSettings() {
    showSettingsBottomSheet(context);
  }

  void _showViewportAdjustDialog(TabManagerVM tabManagerVM) {
    final activeTabId = tabManagerVM.activeTabId;
    if (activeTabId == null) return;
    final activeTab = tabManagerVM.getTab(activeTabId);
    if (activeTab == null) return;
    showDialog(
      context: context,
      builder: (_) => ViewportAdjustDialog(tab: activeTab),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsVM>(
      builder: (context, settingsVM, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackPress();
          },
          child: Scaffold(
          appBar: settingsVM.showAppBar
              ? AppBar(
                  title: const Text('AskMAI - Multi-LLM Chat'),
                  elevation: 0,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Consumer<TabManagerVM>(
                          builder: (context, tabVM, _) {
                            return Text(
                              '${tabVM.tabCount} tab${tabVM.tabCount != 1 ? "s" : ""}',
                              style: const TextStyle(fontSize: 14),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: Consumer3<TabManagerVM, WebViewService, InputDistributorVM>(
              builder: (context, tabManagerVM, webViewService, distributorVM, _) {
                // 过滤只显示isDisplayed=true的tab
                final displayedTabs = tabManagerVM.tabs
                    .where((tab) => tab.isDisplayed)
                    .toList();

                return Column(
                  children: [
                    // WebView容器
                    Expanded(
                      child: displayedTabs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.language,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No tabs added yet',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Click the + button to add your first LLM',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _showAddTabDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Tab'),
                                  ),
                                ],
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final activeTabId = tabManagerVM.activeTabId;
                                return IndexedStack(
                                  index: activeTabId != null
                                      ? displayedTabs
                                              .indexWhere(
                                                (tab) => tab.id == activeTabId,
                                              )
                                              .clamp(0, displayedTabs.length - 1)
                                      : 0,
                                  children: displayedTabs.map((tab) {
                                    final currentTab = tabManagerVM.getTab(tab.id);
                                    return Consumer<TabManagerVM>(
                                      key: ValueKey(tab.id),
                                      builder: (context, vm, _) {
                                        final activeTabWithPreview = vm.activeTab;
                                        final tabToUse =
                                            (activeTabWithPreview != null &&
                                                    activeTabWithPreview.id == tab.id)
                                                ? activeTabWithPreview
                                                : tab;
                                        return WebViewContainer(
                                          tab: tabToUse,
                                          webViewService: webViewService,
                                          tabManagerVM: tabManagerVM,
                                        );
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                    ),

                    // 底部区域: 用户向网页输入时隐藏
                    Consumer2<InputFocusManager, KeyboardVisibilityManager>(
                      builder: (context, focusManager, keyboardManager, _) {
                        final isFlutterInputFocused = focusManager.hasFocus;
                        final isKeyboardVisible = keyboardManager.isVisible;
                        final shouldHide =
                            isKeyboardVisible && !isFlutterInputFocused;

                        return Visibility(
                          visible: !shouldHide,
                          maintainState: true,
                          maintainAnimation: false,
                          maintainSize: false,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08),
                                  blurRadius: AppThemeConfig.shadowBlur,
                                  offset: Offset(0, AppThemeConfig.shadowOffsetY),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 左侧按钮列 + AI tab + 输入框
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _LeftButtonColumn(
                                      onNewChat: _handleNewChat,
                                      onSettings: _handleSettings,
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          LLMTabBar(
                                            tabs: displayedTabs,
                                            tabManagerVM: tabManagerVM,
                                            submissionStatus: distributorVM.submissionStatus,
                                            onAddTab: _showAddTabDialog,
                                            onRefreshTab: _onRefreshTab,
                                          ),
                                          InputArea(
                                            onNewChat: _handleNewChat,
                                            onSettings: _handleSettings,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
}

/// 左侧功能按钮列，独立于输入框
class _LeftButtonColumn extends StatelessWidget {
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  const _LeftButtonColumn({
    required this.onNewChat,
    required this.onSettings,
  });

  static const double spacing = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<TabManagerVM>(
      builder: (context, tabManagerVM, _) {
        final activeTab = tabManagerVM.activeTab;
        final isViewportEnabled = activeTab != null && !activeTab.viewportDisabled;

        return Container(
          width: 48,
          padding: const EdgeInsets.only(left: 10, right: 0, top: 10, bottom: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LeftIconButton(
                icon: Icons.add_comment_rounded,
                onTap: onNewChat,
                theme: theme,
              ),
              const SizedBox(height: spacing),
              _LeftIconButton(
                icon: Icons.view_quilt_rounded,
                onTap: () {
                  final state = context.findAncestorStateOfType<_ChatScreenState>();
                  state?._showViewportAdjustDialog(tabManagerVM);
                },
                theme: theme,
                iconColor: isViewportEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: spacing),
              _LeftIconButton(
                icon: Icons.settings_rounded,
                onTap: onSettings,
                theme: theme,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeftIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  final Color? iconColor;

  const _LeftIconButton({
    required this.icon,
    required this.onTap,
    required this.theme,
    this.iconColor,
  });

  @override
  State<_LeftIconButton> createState() => _LeftIconButtonState();
}

class _LeftIconButtonState extends State<_LeftIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                color: widget.iconColor ?? colorScheme.primary,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}