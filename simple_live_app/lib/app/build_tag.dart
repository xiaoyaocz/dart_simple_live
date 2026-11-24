/// CI 构建时注入的测试包标识（如 "-S1"、"-R1"），本地构建为空字符串。
///
/// 由 GitHub Actions 手动工作流在构建前覆写本文件。iOS 端经
/// `--build-name` 注入后缀会被 Xcode 清洗（版本串变形），故走
/// Dart 常量，日志导出中的 App Version 直接携带该标识。
const String kBuildTag = "";
