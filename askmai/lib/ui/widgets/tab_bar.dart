import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme_config.dart' show AppThemeConfig;
import '../../models/exports.dart';
import '../../viewmodels/exports.dart';

/// 标签栏组件 - 显示和管理多个标签页，集成状态指示
class LLMTabBar extends StatelessWidget {
  final List<LLMTab> tabs;
  final TabManagerVM tabManagerVM;
  final Map<String, SubmissionResult> submissionStatus;
  final VoidCallback onAddTab;
  final void Function(String tabId) onRefreshTab;

  const LLMTabBar({
    Key? key,
    required this.tabs,
    required this.tabManagerVM,
    required this.submissionStatus,
    required this.onAddTab,
    required this.onRefreshTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 8),
            ...tabs.map((tab) {
              final status = submissionStatus[tab.id];
              final webStatus = tabManagerVM.getWebStatus(tab.id);
              return _ModernTabButton(
                key: ValueKey(tab.id),
                tab: tab,
                isActive: tab.id == tabManagerVM.activeTabId,
                status: status,
                webStatus: webStatus,
                onTap: () => tabManagerVM.switchTab(tab.id),
                onClose: () => tabManagerVM.removeTab(tab.id),
                onRefresh: () => onRefreshTab(tab.id),
              );
            }).toList(),

            // 添加标签页按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'Add new tab',
                  child: InkWell(
                    onTap: onAddTab,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// 现代化单个标签页按钮 - 支持状态指示点与无死角自适应气泡菜单
class _ModernTabButton extends StatefulWidget {
  final LLMTab tab;
  final bool isActive;
  final SubmissionResult? status;
  final WebLoadingStatus webStatus;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const _ModernTabButton({
    Key? key,
    required this.tab,
    required this.isActive,
    required this.status,
    required this.webStatus,
    required this.onTap,
    required this.onClose,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<_ModernTabButton> createState() => _ModernTabButtonState();
}

class _ModernTabButtonState extends State<_ModernTabButton> with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Breathing animation fields
  AnimationController? _breathingController;
  Animation<double>? _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _breathingAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController!, curve: Curves.easeInOut),
    );
  }

  void _showContextMenu(BuildContext context) {
    if (_overlayEntry != null) return; // 避免重复显示菜单

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    // 获取当前 Tab 按钮的尺寸和在屏幕上的绝对位置
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final tabSize = renderBox.size;
    final tabOffset = renderBox.localToGlobal(Offset.zero);

    const menuWidth = 180.0;
    const arrowHeight = 6.0;
    const borderRadius = 12.0;
    const arrowWidth = 10.0;

    // 计算相对于 Tab 左上角的 X 偏移量，以使菜单居中
    final double defaultOffsetX = tabSize.width / 2 - menuWidth / 2;
    // 菜单在屏幕上的默认全局 X 坐标
    final double menuGlobalX = tabOffset.dx + defaultOffsetX;
    // 限制菜单在屏幕范围内（左右留出 16.0 间距）
    final double finalGlobalX = menuGlobalX.clamp(16.0, screenSize.width - menuWidth - 16.0);
    // 菜单实际发生的水平位移（向右为正，向左为负）
    final double shift = finalGlobalX - menuGlobalX;

    // 最终应用到 CompositedTransformFollower 的偏移量
    final double finalOffsetX = defaultOffsetX + shift;
    // 气泡箭头的横坐标（相对于菜单左侧的偏移量），并进行边界限制防止箭头画到卡片圆角外部
    final double arrowX = (menuWidth / 2 - shift).clamp(
      borderRadius + arrowWidth / 2,
      menuWidth - borderRadius - arrowWidth / 2,
    );

    // 使用单个 OverlayEntry，内置 GestureDetector 遮罩和 CompositedTransformFollower
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 全屏无色背景遮罩，点击时关闭菜单
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // 紧密跟随 Tab 按钮的悬浮菜单
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // 将菜单的 bottom-left 锚定在 Tab 的 top-left
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            // 传入水平和垂直的偏移量，高度留出 6dp 气泡微小间距
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
                  shadows: AppThemeConfig.menuShadow(theme.brightness == Brightness.dark),
                ),
                child: SizedBox(
                  width: menuWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Consumer<TabManagerVM>(
                      builder: (context, tabManagerVM, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 刷新页面 - 第一
                            MenuOption(
                              icon: Icons.refresh,
                              label: '刷新页面',
                              iconColor: colorScheme.primary,
                              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                              onTap: () {
                                _closeMenu();
                                widget.onRefresh();
                              },
                            ),
                            // 启用/禁用 - 第二
                            MenuOption(
                              icon: widget.tab.isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
                              label: widget.tab.isEnabled ? '禁用标签页' : '启用标签页',
                              iconColor: widget.tab.isEnabled ? Colors.orange : Colors.grey,
                              backgroundColor: (widget.tab.isEnabled ? Colors.orange : Colors.grey)
                                  .withValues(alpha: 0.1),
                              onTap: () {
                                _closeMenu();
                                final willBeEnabled = !widget.tab.isEnabled;
                                final updatedTab = widget.tab.copyWith(
                                  isEnabled: willBeEnabled,
                                  isDisplayed: willBeEnabled ? true : widget.tab.isDisplayed,
                                );
                                tabManagerVM.updateTab(updatedTab);
                              },
                            ),
                            // 隐藏页面 - 第三
                            MenuOption(
                              icon: Icons.visibility_off,
                              label: '隐藏标签页',
                              iconColor: Colors.redAccent,
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                              onTap: () {
                                _closeMenu();
                                final updatedTab = widget.tab.copyWith(
                                  isDisplayed: false,
                                  isEnabled: false,
                                );
                                tabManagerVM.updateTab(updatedTab);
                              },
                              isLast: true,
                            ),
                          ],
                        );
                      },
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

  @override
  void dispose() {
    _breathingController?.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  Widget _buildStatusIndicator(WebLoadingStatus webStatus) {
    if (!widget.tab.isEnabled) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[400]!,
        ),
      );
    }

    final isSubmissionError = widget.status != null && !widget.status!.success;
    final isWebError = webStatus == WebLoadingStatus.error;

    if (isSubmissionError || isWebError) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
        ),
      );
    }

    switch (webStatus) {
      case WebLoadingStatus.loading:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[400]!,
          ),
        );
      case WebLoadingStatus.active:
        return AnimatedBuilder(
          animation: _breathingAnimation!,
          builder: (context, child) {
            final opacity = _breathingAnimation!.value;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: opacity),
              ),
            );
          },
        );
      case WebLoadingStatus.loaded:
      default:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final webStatus = widget.webStatus;

    // Control breathing animation based on status
    if (widget.tab.isEnabled && webStatus == WebLoadingStatus.active) {
      if (!_breathingController!.isAnimating) {
        _breathingController!.repeat(reverse: true);
      }
    } else {
      if (_breathingController!.isAnimating) {
        _breathingController!.stop();
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Material(
          borderRadius: BorderRadius.circular(12),
          color: widget.isActive
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surface, // Clean white (surface) for inactive tabs!
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            onLongPress: () {
              _showContextMenu(context);
            },
            onSecondaryTap: () {
              _showContextMenu(context);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isActive
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : widget.tab.isEnabled
                          ? theme.dividerColor.withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.4), // Gray border when disabled
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标签页标题
                    Flexible(
                      child: Text(
                        widget.tab.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                          color: widget.tab.isEnabled
                              ? (widget.isActive
                                  ? colorScheme.primary
                                  : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))
                              : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4), // Faded when disabled
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 状态指示点
                    _buildStatusIndicator(webStatus),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 菜单选项小部件 - 公开以供复用
class MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool isLast;

  const MenuOption({
    Key? key,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
    this.isLast = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.blue.withValues(alpha: 0.1),
        highlightColor: Colors.blue.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 气泡背景 ShapeBorder - 绘制带向下三角箭头的圆角矩形 - 公开以供复用
class BubbleShapeBorder extends ShapeBorder {
  final double arrowX;
  final double arrowWidth;
  final double arrowHeight;
  final double borderRadius;

  const BubbleShapeBorder({
    required this.arrowX,
    this.arrowWidth = 10.0,
    this.arrowHeight = 6.0,
    this.borderRadius = 12.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: arrowHeight);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final double w = rect.width;
    final double h = rect.height - arrowHeight;
    final double r = borderRadius;
    
    // 气泡下方向下箭头的顶点横坐标，并进行边界夹紧防止超出圆角矩形范围
    final double ax = arrowX.clamp(r + arrowWidth / 2, w - r - arrowWidth / 2);
    final double ay = rect.bottom;

    // 顺时针绘制带下箭头的圆角气泡路径
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
    
    // 底边及指向 Tab 的小三角箭头
    path.lineTo(ax + arrowWidth / 2, h);
    path.lineTo(ax, ay);
    path.lineTo(ax - arrowWidth / 2, h);
    
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.close();
    
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) {
    return BubbleShapeBorder(
      arrowX: arrowX * t,
      arrowWidth: arrowWidth * t,
      arrowHeight: arrowHeight * t,
      borderRadius: borderRadius * t,
    );
  }
}
