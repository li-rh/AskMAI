import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exports.dart';
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

class _SettingsBottomSheet extends StatelessWidget {
  final ScrollController scrollController;

  const _SettingsBottomSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsVM>(
      builder: (context, settingsVM, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SingleChildScrollView(
          controller: scrollController,
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
                child: Column(
                  children: [
                    _ThemeOption(
                      title: '浅色',
                      value: 'light',
                      currentValue: settingsVM.themeMode,
                      onChanged: (value) {
                        settingsVM.setThemeMode(value);
                      },
                    ),
                    _ThemeOption(
                      title: '深色',
                      value: 'dark',
                      currentValue: settingsVM.themeMode,
                      onChanged: (value) {
                        settingsVM.setThemeMode(value);
                      },
                    ),
                    _ThemeOption(
                      title: '跟随系统',
                      value: 'auto',
                      currentValue: settingsVM.themeMode,
                      onChanged: (value) {
                        settingsVM.setThemeMode(value);
                      },
                    ),
                  ],
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
                        value: settingsVM.showAppBar,
                        onChanged: (value) {
                          settingsVM.setShowAppBar(value);
                        },
                        activeThumbColor: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // AI Tab 配置
              Consumer<TabManagerVM>(
                builder: (context, tabManagerVM, _) {
                  return _SettingsSection(
                    title: '已添加的 AI Tab',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tabManagerVM.tabCount} 个标签页',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showTabsJsonEditor(context, tabManagerVM);
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('编辑标签页配置'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 显示标签页列表
                          if (tabManagerVM.tabs.isNotEmpty)
                            Column(
                              children: [
                                const SizedBox(height: 8),
                                ...tabManagerVM.tabs.map((tab) {
                                  return _SettingsTabItem(
                                    key: ValueKey(tab.id),
                                    tab: tab,
                                    tabManagerVM: tabManagerVM,
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 关于
              _SettingsSection(
                title: '关于',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '版本',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '1.0.0',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
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
  final String currentValue;
  final Function(String) onChanged;

  const _ThemeOption({
    required this.title,
    required this.value,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = currentValue == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
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
                groupValue: currentValue,
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
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

  const _SettingsTabItem({
    Key? key,
    required this.tab,
    required this.tabManagerVM,
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
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
    final inputXPathController = TextEditingController(
      text: widget.tab.customInputXPath ?? '',
    );
    final submitXPathController = TextEditingController(
      text: widget.tab.customSubmitXPath ?? '',
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
    bool viewportDisabled = widget.tab.viewportDisabled;

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
                        labelText: '输入框 XPath（可选）',
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
                        labelText: '提交按钮 XPath（可选）',
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
                          value: viewportDisabled,
                          onChanged: (value) {
                            setState(() {
                              viewportDisabled = value ?? false;
                            });
                          },
                        ),
                        const Text('禁用视口调整'),
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
                      viewportDisabled: viewportDisabled,
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
        child: GestureDetector(
          onLongPress: () {
            _showContextMenu(context);
          },
          onSecondaryTap: () {
            _showContextMenu(context);
          },
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
                Expanded(
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
      ),
    );
  }
}

/// 显示标签页JSON编辑器
void _showTabsJsonEditor(BuildContext context, TabManagerVM tabManagerVM) {
  final jsonController = TextEditingController();
  
  // 将tabs转换为JSON
  final tabsJson = tabManagerVM.tabs.map((tab) {
    return {
      'id': tab.id,
      'url': tab.url,
      'displayName': tab.displayName,
      'isEnabled': tab.isEnabled,
      'isDisplayed': tab.isDisplayed,
      'customInputXPath': tab.customInputXPath,
      'customSubmitXPath': tab.customSubmitXPath,
      'viewportTop': tab.viewportTop,
      'viewportBottom': tab.viewportBottom,
      'viewportLeft': tab.viewportLeft,
      'viewportRight': tab.viewportRight,
      'viewportDisabled': tab.viewportDisabled,
      'createdAt': tab.createdAt.toIso8601String(),
    };
  }).toList();
  
  jsonController.text = _prettyPrintJson(tabsJson);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('编辑标签页配置'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: TextField(
            controller: jsonController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '在此编辑JSON配置',
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
                // 解析并应用配置
                _applyTabsJson(context, jsonController.text, tabManagerVM);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('JSON格式错误: $e')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
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

/// 应用编辑后的JSON配置
void _applyTabsJson(BuildContext context, String jsonStr, TabManagerVM tabManagerVM) {
  try {
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    
    // 清空并重新添加tabs
    final newTabs = <LLMTab>[];
    for (final item in jsonList) {
      if (item is! Map<String, dynamic>) continue;
      
      final tab = LLMTab(
        id: item['id'] ?? '',
        url: item['url'] ?? '',
        displayName: item['displayName'] ?? 'Unnamed',
        createdAt: item['createdAt'] != null
            ? DateTime.parse(item['createdAt'])
            : DateTime.now(),
        isEnabled: item['isEnabled'] ?? true,
        isDisplayed: item['isDisplayed'] ?? true,
        customInputXPath: item['customInputXPath'],
        customSubmitXPath: item['customSubmitXPath'],
        viewportTop: (item['viewportTop'] as num?)?.toInt() ?? 0,
        viewportBottom: (item['viewportBottom'] as num?)?.toInt() ?? 0,
        viewportLeft: (item['viewportLeft'] as num?)?.toInt() ?? 0,
        viewportRight: (item['viewportRight'] as num?)?.toInt() ?? 0,
        viewportDisabled: item['viewportDisabled'] as bool? ?? false,
      );
      newTabs.add(tab);
    }
    
    // 替换tabs列表
    tabManagerVM.clearAllTabs().then((_) {
      for (final tab in newTabs) {
        tabManagerVM.addTab(
          tab.url,
          tab.displayName,
          id: tab.id,
          customInputXPath: tab.customInputXPath,
          customSubmitXPath: tab.customSubmitXPath,
          isEnabled: tab.isEnabled,
          isDisplayed: tab.isDisplayed,
          viewportTop: tab.viewportTop,
          viewportBottom: tab.viewportBottom,
          viewportLeft: tab.viewportLeft,
          viewportRight: tab.viewportRight,
          viewportDisabled: tab.viewportDisabled,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
    });
  } catch (e) {
    throw Exception('Failed to parse JSON: $e');
  }
}
