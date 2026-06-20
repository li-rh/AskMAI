import 'injection_strategy.dart';
import 'generic_strategy.dart';
import 'text_filler.dart';

/// 注入策略工厂
///
/// 策略选择指南（在 site_config.json 的 "strategy" 字段中配置）：
///
/// | strategy 名称       | Filler                 | 填充技术                              | 典型站点                  |
/// |---------------------|------------------------|---------------------------------------|---------------------------|
/// | "dom_input"         | DomInputFiller         | Prototype Setter (textarea/input)    | DeepSeek、豆包、智谱、Qwen |
/// | "exec_command"      | ExecCommandFiller      | document.execCommand('insertText')   | ChatGPT、Gemini、Kimi、元宝 |
/// | "input_event"       | InputEventFiller       | InputEvent('beforeinput' + 'input')  | 现代 React contenteditable |
/// | "clipboard_paste"   | ClipboardPasteFiller   | ClipboardEvent('paste')              | 需要粘贴触发的编辑器       |
/// | "react_slate"       | ReactSlateFiller       | React Fiber + Slate Editor API       | 千问                      |
/// | "generic" (默认)    | GenericStrategy        | 旧版兼容（不推荐）                    | 旧配置向后兼容            |
class StrategyFactory {
  static InjectionStrategy getStrategy(String? strategyName) {
    switch (strategyName) {
      case 'dom_input':
        return FillerInjectionStrategy(filler: DomInputFiller());
      case 'exec_command':
        return FillerInjectionStrategy(filler: ExecCommandFiller());
      case 'input_event':
        return FillerInjectionStrategy(filler: InputEventFiller());
      case 'clipboard_paste':
        return FillerInjectionStrategy(filler: ClipboardPasteFiller());
      case 'react_slate':
        return FillerInjectionStrategy(filler: ReactSlateFiller());
      case 'generic':
      default:
        return GenericStrategy();
    }
  }
}
