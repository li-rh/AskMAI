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
  LLMTab? get activeTab =>
      _tabs.firstWhereOrNull((tab) => tab.id == _activeTabId);
  String? get activeTabId => _activeTabId;
  bool get isLoading => _isLoading;
  int get tabCount => _tabs.length;

  /// 添加新标签页
  void addTab(
    String url,
    String displayName, {
    String? customInputXPath,
    String? customSubmitXPath,
    bool isEnabled = true,
    bool isDisplayed = true,
  }) {
    final newTab = LLMTab(
      id: const Uuid().v4(),
      url: url,
      displayName: displayName,
      createdAt: DateTime.now(),
      isEnabled: isEnabled,
      isDisplayed: isDisplayed,
      customInputXPath: customInputXPath,
      customSubmitXPath: customSubmitXPath,
    );

    _tabs.add(newTab);

    // 如果是第一个标签页，设置为活跃
    _activeTabId ??= newTab.id;

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

  /// 更新标签页
  void updateTab(LLMTab updatedTab) {
    final index = _tabs.indexWhere((tab) => tab.id == updatedTab.id);
    if (index != -1) {
      _tabs[index] = updatedTab;
      
      // 如果正在隐藏活跃的标签页，自动切换到第一个可见的标签页
      if (_activeTabId == updatedTab.id && !updatedTab.isDisplayed) {
        final firstVisibleTab = _tabs.firstWhereOrNull((tab) => tab.isDisplayed);
        _activeTabId = firstVisibleTab?.id;
      }
      
      notifyListeners();
      _persistTabs();
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

      // 迁移：隐藏的标签页必须同时禁用（兼容旧数据）
      bool needsPersist = false;
      for (int i = 0; i < _tabs.length; i++) {
        if (!_tabs[i].isDisplayed && _tabs[i].isEnabled) {
          _tabs[i] = _tabs[i].copyWith(isEnabled: false);
          needsPersist = true;
        }
      }
      if (needsPersist) {
        await _prefs.saveTabUrls(_tabs);
      }

      final activeTabId = await _prefs.getActiveTabId();

      if (_tabs.isEmpty) {
        _initDefaultTabs();
      } else {
        _activeTabId = activeTabId ?? _tabs.first.id;
      }
    } catch (e) {
      print('Error restoring tabs: $e');
      if (_tabs.isEmpty) {
        _initDefaultTabs();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 初始化默认标签页（豆包、DeepSeek、千问、元宝）
  void _initDefaultTabs() {
    const defaults = [
      ('https://www.doubao.com', '豆包'),
      ('https://chat.deepseek.com', 'DeepSeek'),
      ('https://www.qianwen.com', '千问'),
      ('https://yuanbao.tencent.com', '元宝'),
    ];

    for (final (url, name) in defaults) {
      final newTab = LLMTab(
        id: const Uuid().v4(),
        url: url,
        displayName: name,
        createdAt: DateTime.now(),
      );
      _tabs.add(newTab);
    }

    _activeTabId = _tabs.first.id;
    _persistTabs();
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

  /// 公共方法：持久化tabs（供外部调用）
  Future<void> persistTabs() async {
    await _persistTabs();
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
