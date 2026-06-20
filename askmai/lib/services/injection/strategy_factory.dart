import 'injection_strategy.dart';
import 'generic_strategy.dart';
import 'text_filler.dart';

/// 注入策略工厂
///
/// 策略选择指南（在 site_config.json 的 "strategy" 字段中配置）：
///
/// | strategy 值         | Filler                 | 适用元素                        | 典型站点                  |
/// |---------------------|------------------------|---------------------------------|---------------------------|
/// | "dom_input"         | DomInputFiller         | <textarea> / <input>            | DeepSeek、豆包            |
/// | "contenteditable"   | ContentEditableFiller  | div[contenteditable]（Quill等） | ChatGPT、Gemini、元宝     |
/// | "react_fiber"       | ReactFiberFiller       | div[contenteditable]（Slate）   | 千问                      |
/// | "generic" (默认)    | GenericStrategy        | 兼容 textarea + contenteditable | 旧配置向后兼容（不推荐）  |
class StrategyFactory {
  static InjectionStrategy getStrategy(String? strategyName) {
    switch (strategyName) {
      case 'dom_input':
        return FillerInjectionStrategy(filler: DomInputFiller());
      case 'contenteditable':
        return FillerInjectionStrategy(filler: ContentEditableFiller());
      case 'react_fiber':
        return FillerInjectionStrategy(filler: ReactFiberFiller());
      case 'generic':
      default:
        return GenericStrategy();
    }
  }
}
