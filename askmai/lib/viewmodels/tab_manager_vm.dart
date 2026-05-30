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

  /// 存储视口调整的预览状态（不持久化）
  final Map<String, LLMTab> _previewTabs = {};

  TabManagerVM(this._prefs);

  // Getters
  List<LLMTab> get tabs => _tabs;
  LLMTab? get activeTab {
    final originalTab = _tabs.firstWhereOrNull((tab) => tab.id == _activeTabId);
    if (originalTab == null) return null;
    // 如果有预览tab，返回预览tab，否则返回原始tab
    return _previewTabs[originalTab.id] ?? originalTab;
  }

  String? get activeTabId => _activeTabId;
  bool get isLoading => _isLoading;
  int get tabCount => _tabs.length;

  /// 添加新标签页
  void addTab(
    String url,
    String displayName, {
    String? id,
    String? customInputXPath,
    String? customSubmitXPath,
    bool isEnabled = true,
    bool isDisplayed = true,
    int viewportTop = 0,
    int viewportBottom = 0,
    int viewportLeft = 0,
    int viewportRight = 0,
    bool viewportDisabled = false,
  }) {
    final newTab = LLMTab(
      id: id ?? const Uuid().v4(),
      url: url,
      displayName: displayName,
      createdAt: DateTime.now(),
      isEnabled: isEnabled,
      isDisplayed: isDisplayed,
      customInputXPath: customInputXPath,
      customSubmitXPath: customSubmitXPath,
      viewportTop: viewportTop,
      viewportBottom: viewportBottom,
      viewportLeft: viewportLeft,
      viewportRight: viewportRight,
      viewportDisabled: viewportDisabled,
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
      // 清除之前活跃标签页的预览状态
      if (_activeTabId != null) {
        clearTabPreview(_activeTabId!);
      }
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

      // 清除预览状态
      clearTabPreview(updatedTab.id);

      // 如果正在隐藏活跃的标签页，自动切换到第一个可见的标签页
      if (_activeTabId == updatedTab.id && !updatedTab.isDisplayed) {
        final firstVisibleTab = _tabs.firstWhereOrNull(
          (tab) => tab.isDisplayed,
        );
        _activeTabId = firstVisibleTab?.id;
      }

      notifyListeners();
      _persistTabs();
    }
  }

  /// 预览更新标签页的视口设置（不持久化，用于对话框实时预览）
  void updateTabPreview(LLMTab updatedTab) {
    // 只更新预览状态，不修改原始_tab数据
    _previewTabs[updatedTab.id] = updatedTab;
    notifyListeners();
  }

  /// 清除指定tab的预览状态
  void clearTabPreview(String tabId) {
    if (_previewTabs.containsKey(tabId)) {
      _previewTabs.remove(tabId);
      notifyListeners();
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
        
        // 自动合并 site_config.json 中新增的模型
        final siteRegistry = SiteRegistry();
        final configs = siteRegistry.getAllConfigs();
        bool isNewTabAdded = false;
        
        for (final config in configs) {
          if (config.isDisplay) {
            final exists = _tabs.any((tab) => tab.displayName == config.displayName);
            if (!exists) {
              String startUrl = config.urlPattern;
              
              _tabs.add(LLMTab(
                id: const Uuid().v4(),
                url: startUrl,
                displayName: config.displayName,
                createdAt: DateTime.now(),
              ));
              isNewTabAdded = true;
            }
          }
        }
        
        if (isNewTabAdded) {
          await _prefs.saveTabUrls(_tabs);
        }
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

  /// 初始化默认标签页（基于site_config.json）
  void _initDefaultTabs() {
    final siteRegistry = SiteRegistry();
    final configs = siteRegistry.getAllConfigs();

    for (final config in configs) {
      if (config.isDisplay) { // 只添加默认显示为 true 的
        String startUrl = config.urlPattern;
        
        final newTab = LLMTab(
          id: const Uuid().v4(),
          url: startUrl,
          displayName: config.displayName,
          createdAt: DateTime.now(),
        );
        _tabs.add(newTab);
      }
    }

    if (_tabs.isNotEmpty) {
      _activeTabId = _tabs.first.id;
    }
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
