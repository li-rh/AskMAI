import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/exports.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';
import 'tab_bar.dart';

/// 设置界面 - 使用 BottomSheet 显示
void showSettingsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 2 / 3,
      maxChildSize: 2 / 3,
      minChildSize: 0.1,
      expand: false,
      builder: (context, scrollController) {
        final colorScheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            // 拖动条 - 固定在顶部，拖动可关闭
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 可滚动内容
            Expanded(
              child: _SettingsBottomSheet(scrollController: scrollController),
            ),
          ],
        );
      },
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
  );
}

class _SettingsBottomSheet extends StatefulWidget {
  final ScrollController scrollController;

  const _SettingsBottomSheet({required this.scrollController});

  @override
  State<_SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<_SettingsBottomSheet> {
  late TabManagerVM _tabManagerVM;
  late AppSettingsVM _appSettingsVM;

  @override
  void initState() {
    super.initState();
    _tabManagerVM = context.read<TabManagerVM>();
    _appSettingsVM = context.read<AppSettingsVM>();

    _tabManagerVM.addListener(_onVMChanged);
    _appSettingsVM.addListener(_onVMChanged);
  }

  @override
  void dispose() {
    _tabManagerVM.removeListener(_onVMChanged);
    _appSettingsVM.removeListener(_onVMChanged);
    super.dispose();
  }

  void _onVMChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '设置',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 主题设置
          _SettingsSection(
            title: '主题',
            child: RadioGroup<String>(
              groupValue: _appSettingsVM.themeMode,
              onChanged: (value) {
                if (value != null) {
                  _appSettingsVM.setThemeMode(value);
                }
              },
              child: const Column(
                children: [
                  _ThemeOption(
                    title: '浅色',
                    value: 'light',
                  ),
                  _ThemeOption(
                    title: '深色',
                    value: 'dark',
                  ),
                  _ThemeOption(
                    title: '跟随系统',
                    value: 'auto',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // AppBar 可见性设置
          _SettingsSection(
            title: '显示',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '显示标题栏',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '显示应用顶部的标题栏',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: _appSettingsVM.showAppBar,
                    onChanged: (value) {
                      _appSettingsVM.setShowAppBar(value);
                    },
                    activeThumbColor: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 网页加载策略设置
          _SettingsSection(
            title: '网页加载策略',
            child: RadioGroup<String>(
              groupValue: _appSettingsVM.webLoadStrategy,
              onChanged: (value) {
                if (value != null) {
                  _appSettingsVM.setWebLoadStrategy(value);
                }
              },
              child: const Column(
                children: [
                  _StrategyOption(
                    title: '仅在切换时加载（极速）',
                    subtitle: '最节省流量和内存，点击标签页才开始加载网页',
                    value: 'lazy',
                  ),
                  _StrategyOption(
                    title: '顺序排队加载（推荐，均衡）',
                    subtitle: '先加载活跃网页，其余网页每隔 1.5 秒依次载入',
                    value: 'sequential',
                  ),
                  _StrategyOption(
                    title: '同时并发加载（常规）',
                    subtitle: '启动应用时在后台同时加载所有网页',
                    value: 'concurrent',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // AI Tab 配置
          _SettingsSection(
            title: '已添加的 AI Tab',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_tabManagerVM.tabCount} 个标签页',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showSiteConfigEditor(context, _tabManagerVM);
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('编辑网站配置'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 显示标签页列表
                  if (_tabManagerVM.tabs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorderItem: (oldIndex, newIndex) {
                        _tabManagerVM.reorderTabs(oldIndex, newIndex);
                      },
                      children: _tabManagerVM.tabs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final tab = entry.value;
                        return _SettingsTabItem(
                          key: ValueKey(tab.id),
                          index: index,
                          tab: tab,
                          tabManagerVM: _tabManagerVM,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 关于
          _SettingsSection(
            title: '关于',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      _showGitHubDialog(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '版本',
                            style: theme.textTheme.titleMedium,
                          ),
                          Row(
                            children: [
                              Text(
                                _appSettingsVM.appVersion,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showGitHubDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.code, color: Colors.blue),
              SizedBox(width: 8),
              Text('访问 GitHub 仓库'),
            ],
          ),
          content: const Text(
            '是否跳转到 AMAi 的 GitHub 开源仓库？\n\n您可以在这里反馈问题、提出建议或查看最新源代码。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '取消',
                style: TextStyle(color: theme.textTheme.bodySmall?.color),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();
                final url = Uri.parse(AppConfig().githubUrl);
                try {
                  bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                  if (!launched) {
                    launched = await launchUrl(url, mode: LaunchMode.platformDefault);
                  }
                  if (!launched) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('无法打开链接，未找到浏览器或处理程序'),
                      ),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('跳转失败: $e'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('跳转'),
            ),
          ],
        );
      },
    );
  }
}

/// 设置分组
class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// 主题选项
class _ThemeOption extends StatelessWidget {
  final String title;
  final String value;

  const _ThemeOption({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          RadioGroup.maybeOf<String>(context)?.onChanged(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium,
              ),
              Radio<String>(
                value: value,
                activeColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 网页加载策略选项
class _StrategyOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final bool isLast;

  const _StrategyOption({
    required this.title,
    required this.subtitle,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groupRegistry = RadioGroup.maybeOf<String>(context);
    final isSelected = groupRegistry?.groupValue == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          RadioGroup.maybeOf<String>(context)?.onChanged(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Radio<String>(
                value: value,
                activeColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置页面的 AI Tab 列表项 - 支持长按菜单（编辑/删除）
class _SettingsTabItem extends StatefulWidget {
  final LLMTab tab;
  final TabManagerVM tabManagerVM;
  final int index;

  const _SettingsTabItem({
    Key? key,
    required this.tab,
    required this.tabManagerVM,
    required this.index,
  }) : super(key: key);

  @override
  State<_SettingsTabItem> createState() => _SettingsTabItemState();
}

class _SettingsTabItemState extends State<_SettingsTabItem> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showContextMenu(BuildContext context) {
    if (_overlayEntry != null) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final tabSize = renderBox.size;
    final tabOffset = renderBox.localToGlobal(Offset.zero);

    const menuWidth = 160.0;
    const arrowHeight = 6.0;
    const borderRadius = 12.0;
    const arrowWidth = 10.0;

    final double defaultOffsetX = tabSize.width / 2 - menuWidth / 2;
    final double menuGlobalX = tabOffset.dx + defaultOffsetX;
    final double finalGlobalX = menuGlobalX.clamp(16.0, screenSize.width - menuWidth - 16.0);
    final double shift = finalGlobalX - menuGlobalX;
    final double finalOffsetX = defaultOffsetX + shift;
    final double arrowX = (menuWidth / 2 - shift).clamp(
      borderRadius + arrowWidth / 2,
      menuWidth - borderRadius - arrowWidth / 2,
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: Offset(finalOffsetX, -6.0),
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: Container(
                decoration: ShapeDecoration(
                  color: colorScheme.surface,
                  shape: BubbleShapeBorder(
                    arrowX: arrowX,
                    arrowHeight: arrowHeight,
                    borderRadius: borderRadius,
                  ),
                  shadows: const [],
                ),
                child: SizedBox(
                  width: menuWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 编辑
                        MenuOption(
                          icon: Icons.edit,
                          label: '编辑',
                          iconColor: Colors.blue,
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          onTap: () {
                            _closeMenu();
                            _showEditTabDialog(context);
                          },
                        ),
                        // 删除
                        MenuOption(
                          icon: Icons.delete,
                          label: '删除',
                          iconColor: Colors.redAccent,
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                          onTap: () {
                            _closeMenu();
                            _showDeleteConfirmDialog(context);
                          },
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final overlay = Overlay.of(context);
    overlay.insert(_overlayEntry!);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 显示编辑 AI Tab 对话框（复用添加标签页的 UI 模式）
  void _showEditTabDialog(BuildContext context) {
    final urlController = TextEditingController(text: widget.tab.url);
    final nameController = TextEditingController(text: widget.tab.displayName);
    
    // 获取该站点在注册表中的默认配置，以支持显示当前生效的 XPath
    final siteConfig = SiteRegistry().getConfigByUrl(widget.tab.url);
    final inputXPathController = TextEditingController(
      text: widget.tab.customInputXPath ?? siteConfig?.inputXPath ?? '',
    );
    final submitXPathController = TextEditingController(
      text: widget.tab.customSubmitXPath ?? siteConfig?.submitXPath ?? '',
    );
    final viewportTopController = TextEditingController(
      text: widget.tab.viewportTop.toString(),
    );
    final viewportBottomController = TextEditingController(
      text: widget.tab.viewportBottom.toString(),
    );
    final viewportLeftController = TextEditingController(
      text: widget.tab.viewportLeft.toString(),
    );
    final viewportRightController = TextEditingController(
      text: widget.tab.viewportRight.toString(),
    );
    bool isEnabled = widget.tab.isEnabled;
    bool isDisplayed = widget.tab.isDisplayed;
    bool viewportEnabled = widget.tab.viewportEnabled;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                '编辑 AI Tab',
                style: TextStyle(fontSize: 16),
              ),
              content: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8),
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
                    const SizedBox(height: 16),
                    const Text(
                      '视口边距设置 (px)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: viewportTopController,
                            decoration: const InputDecoration(
                              labelText: '上边距',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: viewportBottomController,
                            decoration: const InputDecoration(
                              labelText: '下边距',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: viewportLeftController,
                            decoration: const InputDecoration(
                              labelText: '左边距',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: viewportRightController,
                            decoration: const InputDecoration(
                              labelText: '右边距',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: viewportEnabled,
                          onChanged: (value) {
                            setState(() {
                              viewportEnabled = value ?? true;
                            });
                          },
                        ),
                        const Text('启用视口调整'),
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

                    if (!url.startsWith('http://') &&
                        !url.startsWith('https://')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL 必须以 http:// 或 https:// 开头'),
                        ),
                      );
                      return;
                    }

                    final vpTop = int.tryParse(viewportTopController.text.trim()) ?? 0;
                    final vpBottom = int.tryParse(viewportBottomController.text.trim()) ?? 0;
                    final vpLeft = int.tryParse(viewportLeftController.text.trim()) ?? 0;
                    final vpRight = int.tryParse(viewportRightController.text.trim()) ?? 0;

                    // 用更新后的配置替换原标签页
                    widget.tabManagerVM.updateTab(widget.tab.copyWith(
                      url: url,
                      displayName: name,
                      customInputXPath: inputXPathController.text.trim().isEmpty
                          ? null
                          : inputXPathController.text.trim(),
                      customSubmitXPath: submitXPathController.text.trim().isEmpty
                          ? null
                          : submitXPathController.text.trim(),
                      isEnabled: isEnabled,
                      isDisplayed: isDisplayed,
                      viewportTop: vpTop,
                      viewportBottom: vpBottom,
                      viewportLeft: vpLeft,
                      viewportRight: vpRight,
                      viewportEnabled: viewportEnabled,
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除 AI Tab'),
          content: Text('确定要删除 "${widget.tab.displayName}" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.tabManagerVM.removeTab(widget.tab.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.tab.isEnabled
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, left: 4),
                  child: Icon(
                    Icons.drag_handle,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    _showContextMenu(context);
                  },
                  onSecondaryTap: () {
                    _showContextMenu(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tab.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: widget.tab.isEnabled
                              ? theme.textTheme.bodyMedium?.color
                              : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tab.url,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 启用/禁用切换
              Tooltip(
                message: widget.tab.isEnabled ? '禁用' : '启用',
                child: IconButton(
                  icon: Icon(
                    widget.tab.isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: widget.tab.isEnabled ? Colors.orange : Colors.grey,
                  ),
                  onPressed: () {
                    final willBeEnabled = !widget.tab.isEnabled;
                    widget.tabManagerVM.updateTab(widget.tab.copyWith(
                      isEnabled: willBeEnabled,
                      isDisplayed: willBeEnabled ? true : widget.tab.isDisplayed,
                    ));
                  },
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  ),
                ),
                // 显示/隐藏切换
                Tooltip(
                  message: widget.tab.isDisplayed ? '隐藏' : '显示',
                  child: IconButton(
                    icon: Icon(
                      widget.tab.isDisplayed ? Icons.visibility : Icons.visibility_off,
                      color: widget.tab.isDisplayed ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () {
                      final willBeHidden = widget.tab.isDisplayed;
                      widget.tabManagerVM.updateTab(widget.tab.copyWith(
                        isDisplayed: !widget.tab.isDisplayed,
                        isEnabled: willBeHidden ? false : widget.tab.isEnabled,
                      ));
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
}

/// 美化打印JSON
String _prettyPrintJson(dynamic json) {
  try {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  } catch (e) {
    return json.toString();
  }
}

/// 显示网站配置JSON编辑器
void _showSiteConfigEditor(BuildContext context, TabManagerVM tabManagerVM) {
  final jsonController = TextEditingController();
  
  // 从 SiteRegistry 获取当前合并后的配置，并转换为 JSON，同时传入 tabs 以保持开关状态同步
  final siteRegistry = SiteRegistry();
  final configMap = siteRegistry.toMap(tabManagerVM.tabs);
  
  jsonController.text = _prettyPrintJson(configMap);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('编辑全局网站与 UserAgent 配置'),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '修改此处 JSON 将更新 XPath 字段、全局/各站 UserAgent 以及策略配置。直接贴入 site_config.json 格式的 JSON 即可。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: jsonController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '在此编辑或粘贴JSON配置',
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
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
              try {
                // 验证并应用配置
                final jsonStr = jsonController.text;
                // 确保能正常解析
                final decoded = jsonDecode(jsonStr);
                if (decoded is! Map<String, dynamic>) {
                  throw const FormatException('配置根节点必须是 JSON 对象');
                }
                
                tabManagerVM.updateCustomSiteConfig(jsonStr).then((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('网站配置已保存，WebView 已重新加载')),
                    );
                  }
                });
                
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('配置错误: $e')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
}
