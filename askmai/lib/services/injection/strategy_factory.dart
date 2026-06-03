import 'injection_strategy.dart';
import 'generic_strategy.dart';
import 'react_fiber_strategy.dart';
import 'clear_and_paste_strategy.dart';

class StrategyFactory {
  /// 根据策略名称获取注入策略
  static InjectionStrategy getStrategy(String? strategyName) {
    switch (strategyName) {
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

