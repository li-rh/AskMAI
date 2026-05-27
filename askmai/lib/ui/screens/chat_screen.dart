import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';
import '../widgets/exports.dart';

/// 主聊天屏幕
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 默认的 LLM 标签页配置
  static const List<Map<String, String>> _defaultTabs = [
    {'url': 'https://www.doubao.com/chat/', 'name': '豆包'},
    {'url': 'https://chat.deepseek.com/', 'name': 'DeepSeek'},
    {'url': 'https://www.qianwen.com/', 'name': '千问'},
    {'url': 'https://yuanbao.tencent.com/', 'name': '元宝'},
  ];

  @override
  void initState() {
    super.initState();

    // 应用启动时恢复标签页，ViewModel内部会处理初始化默认标签页
    Future.microtask(() async {
      final tabVM = context.read<TabManagerVM>();
      await tabVM.restoreTabs();
    });
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

    // 重置所有tabs的URL为默认值
    for (int i = 0; i < tabVM.tabs.length && i < _defaultTabs.length; i++) {
      final tab = tabVM.tabs[i];
      final defaultUrl = _defaultTabs[i]['url']!;

      // 更新tab的URL
      final updatedTab = tab.copyWith(url: defaultUrl);
      tabVM.updateTab(updatedTab);

      // 重新加载页面
      webViewService.reloadWebView(tab.id);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保系统状态栏始终显示
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsVM>(
      builder: (context, settingsVM, _) {
        return Scaffold(
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
                          : IndexedStack(
                              index: tabManagerVM.activeTab != null
                                  ? displayedTabs
                                        .indexOf(tabManagerVM.activeTab!)
                                        .clamp(0, displayedTabs.length - 1)
                                  : 0,
                              children: displayedTabs.map((tab) {
                                return WebViewContainer(
                                  key: ValueKey(tab.id),
                                  tab: tab,
                                  webViewService: webViewService,
                                  tabManagerVM: tabManagerVM,
                                );
                              }).toList(),
                            ),
                    ),

                    // 底部区域: 用户向网页输入时隐藏 (输入框无焦点 + 软键盘弹出)
                    Consumer2<InputFocusManager, KeyboardVisibilityManager>(
                      builder: (context, focusManager, keyboardManager, _) {
                        final isFlutterInputFocused = focusManager.hasFocus;
                        final isKeyboardVisible = keyboardManager.isVisible;
                        final shouldHide = isKeyboardVisible && !isFlutterInputFocused;

                        return Visibility(
                          visible: !shouldHide,
                          maintainState: true,
                          maintainAnimation: false,
                          maintainSize: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 标签栏
                              LLMTabBar(
                                tabs: displayedTabs,
                                tabManagerVM: tabManagerVM,
                                submissionStatus:
                                    distributorVM.submissionStatus,
                                onAddTab: _showAddTabDialog,
                                onRefreshTab: _onRefreshTab,
                              ),
                              // 输入框
                              InputArea(
                                onNewChat: _handleNewChat,
                                onSettings: _handleSettings,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
