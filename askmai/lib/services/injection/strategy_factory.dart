import 'injection_strategy.dart';
import 'generic_strategy.dart';
import 'react_fiber_strategy.dart';

class StrategyFactory {
  /// 根据策略名称获取注入策略
  static InjectionStrategy getStrategy(String? strategyName) {
    switch (strategyName) {
      case 'react_fiber':
        return ReactFiberStrategy();
      case 'generic':
      default:
        return GenericStrategy();
    }
  }
}
