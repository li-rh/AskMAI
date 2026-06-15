import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/exports.dart';
import '../../viewmodels/exports.dart';

void showAggregateDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _AggregateDialogContent(),
  );
}

class _AggregateDialogContent extends StatefulWidget {
  const _AggregateDialogContent();

  @override
  State<_AggregateDialogContent> createState() => _AggregateDialogContentState();
}

class _AggregateDialogContentState extends State<_AggregateDialogContent> {
  String? _selectedTabId;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PreferencesService>();
    final tabManager = context.read<TabManagerVM>();
    final lastId = prefs.getLastAggregateTargetId();
    final eligibleTabs = tabManager.tabs
        .where((t) => t.isEnabled && t.isDisplayed)
        .toList();
    if (eligibleTabs.isNotEmpty) {
      final match = eligibleTabs.any((t) => t.id == lastId);
      _selectedTabId = match ? lastId : eligibleTabs.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AggregationVM, TabManagerVM, PreferencesService>(
      builder: (context, aggVM, tabManagerVM, prefsService, _) {
        final eligibleTabs = tabManagerVM.tabs
            .where((t) => t.isEnabled && t.isDisplayed)
            .toList();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '选择聚合目标',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _selectedTabId ?? '',
                onChanged: aggVM.isAggregating
                    ? (_) {}
                    : (value) {
                        setState(() => _selectedTabId = value);
                      },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: eligibleTabs
                      .map((tab) => RadioListTile<String>(
                            value: tab.id,
                            title: Text(tab.displayName),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: aggVM.isAggregating
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_selectedTabId == null || aggVM.isAggregating)
                        ? null
                        : () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final result =
                                await aggVM.aggregate(_selectedTabId!);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result.message),
                                  duration: const Duration(seconds: 3),
                                  backgroundColor: result.success
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              );
                            }
                          },
                    child: aggVM.isAggregating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('发送'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
