import 'package:flutter/material.dart';
import '../../models/exports.dart';
import '../../viewmodels/exports.dart';

/// 标签栏组件 - 显示和管理多个标签页
class LLMTabBar extends StatelessWidget {
  final List<LLMTab> tabs;
  final TabManagerVM tabManagerVM;
  final VoidCallback onAddTab;
  final void Function(String tabId) onRefreshTab;

  const LLMTabBar({
    Key? key,
    required this.tabs,
    required this.tabManagerVM,
    required this.onAddTab,
    required this.onRefreshTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        color: Colors.grey[50],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 标签页列表
            ...tabs.map((tab) {
              return _TabButton(
                tab: tab,
                isActive: tab.id == tabManagerVM.activeTabId,
                onTap: () => tabManagerVM.switchTab(tab.id),
                onClose: () => tabManagerVM.removeTab(tab.id),
                onRefresh: () => onRefreshTab(tab.id),
              );
            }).toList(),

            // 添加标签页按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'Add new tab',
                  child: InkWell(
                    onTap: onAddTab,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个标签页按钮
class _TabButton extends StatelessWidget {
  final LLMTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const _TabButton({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.onRefresh,
  });

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20),
              SizedBox(width: 8),
              Text('Refresh Page'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'close',
          child: Row(
            children: [
              Icon(Icons.close, size: 20),
              SizedBox(width: 8),
              Text('Close Tab'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'refresh') {
        onRefresh();
      } else if (value == 'close') {
        onClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
          color: isActive ? Colors.white : Colors.grey[50],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标签页标题
              Flexible(
                child: Text(
                  tab.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 关闭按钮
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
