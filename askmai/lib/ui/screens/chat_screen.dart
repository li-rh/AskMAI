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
  late TabManagerVM _tabManagerVM;
  late ScrollController _scrollController;

  @override
  void dispose() {
    _tabManagerVM.removeListener(_onTabManagerChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

  Future<void> _handleBackPress() async {
    if (!mounted) return;

    // 1. 优先检测并关闭软键盘（执行 JS blur 确保原生 WebView 中的输入框失去焦点，收起键盘）
    try {
      final keyboardManager = context.read<KeyboardVisibilityManager>();
      if (keyboardManager.isVisible) {
        final tabVM = context.read<TabManagerVM>();
        final activeTabId = tabVM.activeTabId;
        if (activeTabId != null) {
          final webViewService = context.read<WebViewService>();
          final controller = webViewService.getWebView(activeTabId);
          if (controller != null) {
            await controller.runJavaScript(
              'if (document.activeElement) { document.activeElement.blur(); }'
            );
          }
        }
        FocusManager.instance.primaryFocus?.unfocus();
        return;
      }
    } catch (e) {
      debugPrint('[BackPress] Error closing native keyboard: $e');
    }

    // 2. 检查 WebView 是否可以后退
    try {
      final tabVM = context.read<TabManagerVM>();
      final activeTabId = tabVM.activeTabId;
      if (activeTabId != null) {
        final webViewService = context.read<WebViewService>();
        final controller = webViewService.getWebView(activeTabId);
        if (controller != null) {
          final canGoBack = await controller.canGoBack();
          if (canGoBack) {
            await controller.goBack();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[BackPress] Error handling webview back navigation: $e');
    }

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
    _tabManagerVM = context.read<TabManagerVM>();
    _tabManagerVM.addListener(_onTabManagerChanged);

    _scrollController = ScrollController(
      initialScrollOffset: 0.0,
    );
    _scrollController.addListener(_onScroll);

    // 应用启动时恢复标签页，ViewModel内部会处理初始化默认标签页
    Future.microtask(() async {
      await _tabManagerVM.restoreTabs();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double width = MediaQuery.of(context).size.width;
    if (width <= 0) return;

    final displayedTabs = _tabManagerVM.tabs.where((tab) => tab.isDisplayed).toList();
    if (displayedTabs.isEmpty) return;

    final double offset = _scrollController.offset;
    final int index = (offset / width).round().clamp(0, displayedTabs.length - 1);

    final targetTab = displayedTabs[index];
    if (_tabManagerVM.activeTabId != targetTab.id) {
      Future.microtask(() {
        if (mounted && _tabManagerVM.activeTabId != targetTab.id) {
          _tabManagerVM.switchTab(targetTab.id);
        }
      });
    }
  }

  void _onTabManagerChanged() {
    if (mounted) {
      final displayedTabs = _tabManagerVM.tabs.where((tab) => tab.isDisplayed).toList();
      final activeIndex = displayedTabs.indexWhere((tab) => tab.id == _tabManagerVM.activeTabId);
      if (activeIndex != -1) {
        final double width = MediaQuery.of(context).size.width;
        if (width > 0) {
          if (_scrollController.hasClients) {
            final int currentScrollIndex = (_scrollController.offset / width).round();
            if (currentScrollIndex != activeIndex) {
              _scrollController.animateTo(
                activeIndex * width,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } else {
            final double initialOffset = activeIndex * width;
            if (_scrollController.initialScrollOffset != initialOffset) {
              _scrollController.removeListener(_onScroll);
              _scrollController.dispose();
              _scrollController = ScrollController(initialScrollOffset: initialOffset);
              _scrollController.addListener(_onScroll);
            }
          }
        }
      }
      setState(() {});
    }
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
              title: const Text('添加新标签页'),
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
                        labelText: '显示名称',
                        hintText: 'ChatGPT',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: inputXPathController,
                      decoration: const InputDecoration(
                        labelText: '输入框 XPath',
                        hintText: '//textarea[@placeholder="..."]',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: submitXPathController,
                      decoration: const InputDecoration(
                        labelText: '提交按钮 XPath',
                        hintText: '//button[@id="send"]',
                        border: OutlineInputBorder(),
                      ),
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
                              const Text('启用'),
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
                              const Text('显示'),
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
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final url = urlController.text.trim();
                    final name = nameController.text.trim();

                    if (url.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('请填写 URL 和显示名称'),
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
                            'URL 必须以 http:// 或 https:// 开头',
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
                  child: const Text('添加'),
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
                  title: const Text('AMAi - Ask Multi-Ai'),
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
            child: Consumer<TabManagerVM>(
              builder: (context, tabManagerVM, _) {
                final webViewService = context.read<WebViewService>();
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
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final height = constraints.maxHeight;

                                return SingleChildScrollView(
                                  controller: _scrollController,
                                  scrollDirection: Axis.horizontal,
                                  physics: const PageScrollPhysics(),
                                  child: Row(
                                    children: displayedTabs.map((tab) {
                                      final activeTabWithPreview = tabManagerVM.activeTab;
                                      final tabToUse =
                                          (activeTabWithPreview != null &&
                                                  activeTabWithPreview.id == tab.id)
                                              ? activeTabWithPreview
                                              : tab;
                                      return SizedBox(
                                        width: width,
                                        height: height,
                                        child: WebViewContainer(
                                          key: ValueKey(tab.id),
                                          tab: tabToUse,
                                          webViewService: webViewService,
                                          tabManagerVM: tabManagerVM,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            )
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
                                          Consumer<InputDistributorVM>(
                                            builder: (context, distributorVM, _) {
                                              return LLMTabBar(
                                                tabs: displayedTabs,
                                                tabManagerVM: tabManagerVM,
                                                submissionStatus: distributorVM.submissionStatus,
                                                onAddTab: _showAddTabDialog,
                                                onRefreshTab: _onRefreshTab,
                                              );
                                            },
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
        final isViewportEnabled = activeTab != null && activeTab.viewportEnabled;

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