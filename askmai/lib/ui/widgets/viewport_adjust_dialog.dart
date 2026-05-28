import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exports.dart';
import '../../viewmodels/exports.dart';

class ViewportAdjustDialog extends StatefulWidget {
  final LLMTab tab;

  const ViewportAdjustDialog({Key? key, required this.tab}) : super(key: key);

  @override
  State<ViewportAdjustDialog> createState() => _ViewportAdjustDialogState();
}

class _ViewportAdjustDialogState extends State<ViewportAdjustDialog> {
  late int _top;
  late int _bottom;
  late int _left;
  late int _right;
  bool _isDisabled = false;
  bool _didSave = false;

  @override
  void initState() {
    super.initState();
    _top = widget.tab.viewportTop;
    _bottom = widget.tab.viewportBottom;
    _left = widget.tab.viewportLeft;
    _right = widget.tab.viewportRight;
    _isDisabled = widget.tab.viewportDisabled;
  }

  @override
  void dispose() {
    if (!_didSave) {
      final tabManagerVM = context.read<TabManagerVM>();
      tabManagerVM.clearTabPreview(widget.tab.id);
    }
    super.dispose();
  }

  void _applyPreview(int top, int bottom, int left, int right) {
    final tabManagerVM = context.read<TabManagerVM>();
    final previewTab = widget.tab.copyWith(
      viewportTop: top,
      viewportBottom: bottom,
      viewportLeft: left,
      viewportRight: right,
      viewportDisabled: _isDisabled,
    );
    tabManagerVM.updateTabPreview(previewTab);
  }

  void _saveAndClose() {
    _didSave = true;
    final tabManagerVM = context.read<TabManagerVM>();
    final updatedTab = widget.tab.copyWith(
      viewportTop: _top,
      viewportBottom: _bottom,
      viewportLeft: _left,
      viewportRight: _right,
      viewportDisabled: _isDisabled,
    );
    tabManagerVM.updateTab(updatedTab);
    Navigator.pop(context);
  }

  void _cancelAndClose() {
    _didSave = false;
    final tabManagerVM = context.read<TabManagerVM>();
    tabManagerVM.clearTabPreview(widget.tab.id);
    Navigator.pop(context);
  }

  void _toggleDisabled() {
    setState(() {
      _isDisabled = !_isDisabled;
    });
    _applyPreview(
      _isDisabled ? 0 : _top,
      _isDisabled ? 0 : _bottom,
      _isDisabled ? 0 : _left,
      _isDisabled ? 0 : _right,
    );
  }

  int get _effectiveTop => _top;
  int get _effectiveBottom => _bottom;
  int get _effectiveLeft => _left;
  int get _effectiveRight => _right;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop && !_didSave) {
          final tabManagerVM = context.read<TabManagerVM>();
          tabManagerVM.clearTabPreview(widget.tab.id);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_quilt_rounded,
                    color: _isDisabled ? Colors.grey : colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '视图调整 - ${widget.tab.displayName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _isDisabled ? Colors.grey : null,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: _isDisabled ? '启用视口调整' : '临时禁用视口调整',
                    child: IconButton(
                      onPressed: _toggleDisabled,
                      icon: Icon(
                        _isDisabled ? Icons.toggle_off : Icons.toggle_on,
                        color: _isDisabled ? Colors.grey : colorScheme.primary,
                      ),
                      tooltip: _isDisabled ? '启用' : '禁用',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isDisabled
                    ? '视口调整已临时禁用，配置值已保留'
                    : '拖动滑块实时调整网页视口边距，隐藏顶部工具栏和底部输入框',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _ViewportSlider(
                label: '隐藏顶部',
                icon: Icons.arrow_upward,
                value: _effectiveTop,
                enabled: !_isDisabled,
                onChanged: (v) {
                  setState(() => _top = v);
                  _applyPreview(_top, _bottom, _left, _right);
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 8),

              _ViewportSlider(
                label: '隐藏底部',
                icon: Icons.arrow_downward,
                value: _effectiveBottom,
                enabled: !_isDisabled,
                onChanged: (v) {
                  setState(() => _bottom = v);
                  _applyPreview(_top, _bottom, _left, _right);
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 8),

              _ViewportSlider(
                label: '隐藏左侧',
                icon: Icons.arrow_back,
                value: _effectiveLeft,
                enabled: !_isDisabled,
                onChanged: (v) {
                  setState(() => _left = v);
                  _applyPreview(_top, _bottom, _left, _right);
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 8),

              _ViewportSlider(
                label: '隐藏右侧',
                icon: Icons.arrow_forward,
                value: _effectiveRight,
                enabled: !_isDisabled,
                onChanged: (v) {
                  setState(() => _right = v);
                  _applyPreview(_top, _bottom, _left, _right);
                },
                colorScheme: colorScheme,
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelAndClose,
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveAndClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewportSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final ColorScheme colorScheme;

  const _ViewportSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? colorScheme.primary : Colors.grey;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 13,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 300,
              divisions: 300,
              activeColor: effectiveColor,
              inactiveColor: effectiveColor.withValues(alpha: 0.2),
              onChanged: enabled ? (v) => onChanged(v.round()) : null,
            ),
          ),
        ],
      ),
    );
  }
}
