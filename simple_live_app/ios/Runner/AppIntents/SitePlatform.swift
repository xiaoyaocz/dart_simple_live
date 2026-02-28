import AppIntents

@available(iOS 16.0, *)
enum SitePlatform: String, AppEnum {
  case bilibili
  case douyu
  case huya
  case douyin

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "直播平台")

  static var caseDisplayRepresentations: [SitePlatform: DisplayRepresentation] = [
    .bilibili: DisplayRepresentation(title: "哔哩哔哩"),
    .douyu: DisplayRepresentation(title: "斗鱼"),
    .huya: DisplayRepresentation(title: "虎牙"),
    .douyin: DisplayRepresentation(title: "抖音"),
  ]
}
