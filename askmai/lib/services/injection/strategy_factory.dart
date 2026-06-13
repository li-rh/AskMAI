import 'injection_strategy.dart';
import 'generic_strategy.dart';
import 'dom_input_strategy.dart';
import 'contenteditable_strategy.dart';
import 'react_fiber_strategy.dart';
import 'clear_and_paste_strategy.dart';

/// 注入策略工厂
///
/// 策略选择指南（在 site_config.json 的 "strategy" 字段中配置）：
///
/// | strategy 值         | 类                        | 适用元素                        | 典型站点                  |
/// |---------------------|---------------------------|---------------------------------|---------------------------|
/// | "dom_input"         | DomInputStrategy          | <textarea> / <input>            | DeepSeek、豆包            |
/// | "contenteditable"   | ContentEditableStrategy   | div[contenteditable]（Quill等） | 元宝                      |
/// | "react_fiber"       | ReactFiberStrategy        | div[contenteditable]（Slate）   | 千问                      |
/// | "clear_and_paste"   | ClearAndPasteStrategy     | 任意（粘贴注入）                | 残留内容场景              |
/// | "generic" (默认)    | GenericStrategy           | 兼容 textarea + contenteditable | 旧配置向后兼容（不推荐）  |
class StrategyFactory {
  static InjectionStrategy getStrategy(String? strategyName) {
    switch (strategyName) {
      case 'dom_input':
        return DomInputStrategy();
      case 'contenteditable':
        return ContentEditableStrategy();
      case 'react_fiber':
        return ReactFiberStrategy();
      case 'clear_and_paste':
        return ClearAndPasteStrategy();
      case 'generic':
      default:
        return GenericStrategy();
    }
  }
}
