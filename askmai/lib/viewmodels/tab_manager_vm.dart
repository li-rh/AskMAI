import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/exports.dart';
import '../services/exports.dart';

/// 标签页管理ViewModel - 使用Provider
class TabManagerVM extends ChangeNotifier {
  final PreferencesService _prefs;

  List<LLMTab> _tabs = [];
  String? _activeTabId;
  bool _isLoading = false;

  TabManagerVM(this._prefs);

  // Getters
  List<LLMTab> get tabs => _tabs;
  LLMTab? get activeTab => _tabs.firstWhereOrNull(
        (tab) => tab.id == _activeTabId,
      );
  String? get activeTabId => _activeTabId;
  bool get isLoading => _isLoading;
  int get tabCount => _tabs.length;

  /// 添加新标签页
  void addTab(String url, String displayName) {
    final newTab = LLMTab(
      id: const Uuid().v4(),
      url: url,
      displayName: displayName,
      createdAt: DateTime.now(),
    );

    _tabs.add(newTab);

    // 如果是第一个标签页，设置为活跃
    if (_activeTabId == null) {
      _activeTabId = newTab.id;
    }

    notifyListeners();
    _persistTabs();
  }

  /// 删除标签页
  void removeTab(String tabId) {
    _tabs.removeWhere((tab) => tab.id == tabId);

    // 如果删除的是活跃标签页，切换到其他的
    if (_activeTabId == tabId) {
      _activeTabId = _tabs.isNotEmpty ? _tabs.first.id : null;
    }

    notifyListeners();
    _persistTabs();
  }

  /// 切换活跃标签页
  void switchTab(String tabId) {
    if (_tabs.any((tab) => tab.id == tabId)) {
      _activeTabId = tabId;
      notifyListeners();
    }
  }

  /// 更新标签页WebViewController
  void setWebViewController(String tabId, dynamic controller) {
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index != -1) {
      _tabs[index].webViewController = controller;
    }
  }

  /// 获取标签页
  LLMTab? getTab(String tabId) {
    try {
      return _tabs.firstWhere((tab) => tab.id == tabId);
    } catch (e) {
      return null;
    }
  }

  /// 检查标签页是否存在
  bool hasTab(String tabId) {
    return _tabs.any((tab) => tab.id == tabId);
  }

  /// 重新排序标签页
  void reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);
    notifyListeners();
    _persistTabs();
  }

  /// 从SharedPreferences恢复标签页
  Future<void> restoreTabs() async {
    try {
      _isLoading = true;
      notifyListeners();

      _tabs = await _prefs.getTabUrls();
      final activeTabId = await _prefs.getActiveTabId();

      if (_tabs.isNotEmpty) {
        _activeTabId = activeTabId ?? _tabs.first.id;
      }
    } catch (e) {
      print('Error restoring tabs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清空所有标签页
  Future<void> clearAllTabs() async {
    _tabs.clear();
    _activeTabId = null;
    notifyListeners();
    await _prefs.clearAll();
  }

  // Private methods
  Future<void> _persistTabs() async {
    await _prefs.saveTabUrls(_tabs);
    if (_activeTabId != null) {
      await _prefs.saveActiveTabId(_activeTabId!);
    }
  }

  @override
  String toString() =>
      'TabManagerVM(tabs: ${_tabs.length}, active: $_activeTabId)';
}

extension on List<LLMTab> {
  LLMTab? firstWhereOrNull(bool Function(LLMTab) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
