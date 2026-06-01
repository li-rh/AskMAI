/// Web加载与活跃状态
enum WebLoadingStatus {
  /// 网页正在加载（灰色）
  loading,

  /// 网页加载完毕且处于静止状态（绿色）
  loaded,

  /// 网页DOM正在发生变化，比如流式输出中（绿色呼吸灯）
  active,

  /// 网页加载或执行出错（红色）
  error,
}
