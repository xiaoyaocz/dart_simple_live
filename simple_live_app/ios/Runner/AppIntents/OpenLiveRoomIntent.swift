import AppIntents

@available(iOS 16.0, *)
struct OpenLiveRoomIntent: AppIntent {
  static var title: LocalizedStringResource = "打开直播间"
  static var description = IntentDescription("输入直播链接，自动解析并跳转直播间")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "直播链接")
  var url: String

  static var parameterSummary: some ParameterSummary {
    Summary("打开 \(\.$url)")
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    AppIntentBridge.shared.sendIntent([
      "action": "open",
      "url": url,
    ])
    return .result()
  }
}
