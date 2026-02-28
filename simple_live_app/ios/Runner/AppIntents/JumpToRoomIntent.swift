import AppIntents

@available(iOS 16.0, *)
struct JumpToRoomIntent: AppIntent {
  static var title: LocalizedStringResource = "跳转直播间"
  static var description = IntentDescription("指定平台和房间号，直接跳转直播间")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "平台")
  var site: SitePlatform

  @Parameter(title: "房间号")
  var roomId: String

  static var parameterSummary: some ParameterSummary {
    Summary("在 \(\.$site) 打开房间 \(\.$roomId)")
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    AppIntentBridge.shared.sendIntent([
      "action": "room",
      "site": site.rawValue,
      "roomId": roomId,
    ])
    return .result()
  }
}
