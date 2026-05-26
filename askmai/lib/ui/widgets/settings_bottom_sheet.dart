import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
