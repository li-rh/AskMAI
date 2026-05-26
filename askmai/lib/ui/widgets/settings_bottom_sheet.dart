import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exports.dart';
import '../../viewmodels/exports.dart';

/// 设置界面 - 使用 BottomSheet 显示
void showSettingsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) => const _SettingsBottomSheet(),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
  );
}

class _SettingsBottomSheet extends StatelessWidget {
  const _SettingsBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsVM>(
      builder: (context, settingsVM, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动条
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

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
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: tab.isEnabled
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
                                                  tab.displayName,
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: tab.isEnabled
                                                        ? theme.textTheme.bodyMedium?.color
                                                        : Colors.grey,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  tab.url,
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
                                          Column(
                                            children: [
                                              Tooltip(
                                                message: tab.isEnabled ? 'Disable' : 'Enable',
                                                child: IconButton(
                                                  icon: Icon(
                                                    tab.isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
                                                    color: tab.isEnabled ? Colors.orange : Colors.grey,
                                                  ),
                                                  onPressed: () {
                                                    tabManagerVM.updateTab(tab.copyWith(isEnabled: !tab.isEnabled));
                                                  },
                                                  iconSize: 20,
                                                  padding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                              Tooltip(
                                                message: tab.isDisplayed ? 'Hide' : 'Show',
                                                child: IconButton(
                                                  icon: Icon(
                                                    tab.isDisplayed ? Icons.visibility : Icons.visibility_off,
                                                    color: tab.isDisplayed ? Colors.blue : Colors.grey,
                                                  ),
                                                  onPressed: () {
                                                    tabManagerVM.updateTab(tab.copyWith(isDisplayed: !tab.isDisplayed));
                                                  },
                                                  iconSize: 20,
                                                  padding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
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
    final encoder = JsonEncoder.withIndent('  ');
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
      );
      newTabs.add(tab);
    }
    
    // 替换tabs列表
    tabManagerVM.clearAllTabs().then((_) {
      for (final tab in newTabs) {
        tabManagerVM.addTab(
          tab.url,
          tab.displayName,
          customInputXPath: tab.customInputXPath,
          customSubmitXPath: tab.customSubmitXPath,
          isEnabled: tab.isEnabled,
          isDisplayed: tab.isDisplayed,
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
