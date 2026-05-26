import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exports.dart';
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
  @override
  void initState() {
    super.initState();

    // 应用启动时恢复标签页，如果没有则添加默认标签页
    Future.microtask(() async {
      final tabVM = context.read<TabManagerVM>();
      await tabVM.restoreTabs();
      if (tabVM.tabs.isEmpty) {
        tabVM.addTab('https://www.doubao.com/chat/', '豆包');
        tabVM.addTab('https://chat.deepseek.com/', 'DeepSeek');
        tabVM.addTab('https://www.qianwen.com/', '千问');
        tabVM.addTab('https://yuanbao.tencent.com/', '元宝');
      }
    });
  }

  void _showAddTabDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Tab'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://chat.openai.com',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'ChatGPT',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
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
                      content: Text('Please fill in all fields'),
                    ),
                  );
                  return;
                }

                // 验证URL格式
                if (!url.startsWith('http://') &&
                    !url.startsWith('https://')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL must start with http:// or https://'),
                    ),
                  );
                  return;
                }

                context.read<TabManagerVM>().addTab(url, name);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _onRefreshTab(String tabId) {
    context.read<WebViewService>().reloadWebView(tabId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AskMAI - Multi-LLM Chat'),
        elevation: 1,
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
      ),
      body: Consumer3<TabManagerVM, WebViewService, InputDistributorVM>(
        builder: (context, tabManagerVM, webViewService, distributorVM, _) {
          return Column(
            children: [
              // 标签栏
              LLMTabBar(
                tabs: tabManagerVM.tabs,
                tabManagerVM: tabManagerVM,
                onAddTab: _showAddTabDialog,
                onRefreshTab: _onRefreshTab,
              ),

              // WebView容器
              Expanded(
                child: tabManagerVM.tabs.isEmpty
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
                              style:
                                  Theme.of(context).textTheme.titleLarge,
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
                            ? tabManagerVM.tabs.indexOf(tabManagerVM.activeTab!).clamp(0, tabManagerVM.tabs.length - 1)
                            : 0,
                        children: tabManagerVM.tabs.map((tab) {
                          return WebViewContainer(
                            key: ValueKey(tab.id),
                            tab: tab,
                            webViewService: webViewService,
                            tabManagerVM: tabManagerVM,
                          );
                        }).toList(),
                      ),
              ),

              // 显示提交状态反馈
              if (distributorVM.hasRecentSubmissions())
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[100],
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var entry in distributorVM.submissionStatus.entries)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Chip(
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tabManagerVM.getTab(entry.key)?.displayName ?? entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  if (!entry.value.success && entry.value.error != null)
                                    Text(
                                      entry.value.error!,
                                      style: const TextStyle(fontSize: 10),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              backgroundColor: entry.value.success
                                  ? Colors.green[200]
                                  : Colors.red[200],
                              avatar: entry.value.success
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.green)
                                  : const Icon(Icons.close,
                                      size: 16, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // 输入框
              const InputArea(),
            ],
          );
        },
      ),
    );
  }
}
