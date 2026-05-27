import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exports.dart';
import '../../viewmodels/exports.dart';

class ViewportAdjustDialog extends StatefulWidget {
  final LLMTab tab;

  const ViewportAdjustDialog({
    Key? key,
    required this.tab,
  }) : super(key: key);

  @override
  State<ViewportAdjustDialog> createState() => _ViewportAdjustDialogState();
}

class _ViewportAdjustDialogState extends State<ViewportAdjustDialog> {
  late int _top;
  late int _bottom;
  late int _left;
  late int _right;

  @override
  void initState() {
    super.initState();
    _top = widget.tab.viewportTop;
    _bottom = widget.tab.viewportBottom;
    _left = widget.tab.viewportLeft;
    _right = widget.tab.viewportRight;
  }

  void _applyPreview(int top, int bottom, int left, int right) {
    final tabManagerVM = context.read<TabManagerVM>();
    final previewTab = widget.tab.copyWith(
      viewportTop: top,
      viewportBottom: bottom,
      viewportLeft: left,
      viewportRight: right,
    );
    tabManagerVM.updateTabPreview(previewTab);
  }

  void _saveAndClose() {
    final tabManagerVM = context.read<TabManagerVM>();
    final updatedTab = widget.tab.copyWith(
      viewportTop: _top,
      viewportBottom: _bottom,
      viewportLeft: _left,
      viewportRight: _right,
    );
    tabManagerVM.updateTab(updatedTab);
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _top = 0;
      _bottom = 0;
      _left = 0;
      _right = 0;
    });
    _applyPreview(0, 0, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
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
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '视图调整 - ${widget.tab.displayName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '拖动滑块实时调整网页视口边距，隐藏顶部工具栏和底部输入框',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),

            _ViewportSlider(
              label: '隐藏顶部',
              icon: Icons.arrow_upward,
              value: _top,
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
              value: _bottom,
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
              value: _left,
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
              value: _right,
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
                    onPressed: _reset,
                    child: const Text('重置'),
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
    );
  }
}

class _ViewportSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final ValueChanged<int> onChanged;
  final ColorScheme colorScheme;

  const _ViewportSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 300,
            divisions: 300,
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.primary.withValues(alpha: 0.2),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}