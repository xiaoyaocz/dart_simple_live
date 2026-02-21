import AppIntents

@available(iOS 16.4, *)
struct SimpleLiveShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenLiveRoomIntent(),
      phrases: [
        "用\(.applicationName)打开直播间",
        "在\(.applicationName)打开直播间",
      ],
      shortTitle: "打开直播间",
      systemImageName: "play.tv"
    )
    AppShortcut(
      intent: JumpToRoomIntent(),
      phrases: [
        "用\(.applicationName)跳转直播间",
        "在\(.applicationName)跳转直播间",
      ],
      shortTitle: "跳转直播间",
      systemImageName: "arrow.right.circle"
    )
  }
}
