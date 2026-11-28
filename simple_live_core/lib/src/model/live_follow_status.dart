/// 关注列表单次状态刷新返回的轻量聚合结果。
class LiveFollowStatus {
  /// 是否正在直播
  final bool isLive;

  /// 解析后的规范房间号（例如虎牙短链/别名、B站短号、斗鱼靓号对应的数字房号）
  final String? resolvedRoomId;

  /// 当前在线人数/热度
  final int? online;

  /// 当前分类/分区名称
  final String? categoryName;

  /// 开播时间戳（秒级 Unix 时间戳字符串）
  final String? showTime;

  /// 直播间标题
  final String? title;

  /// 原始网页分类 ID（用于抖音"游戏"等泛分类二阶段精确查表，避免二次请求房间详情）
  final String? categoryId;

  /// 原始网页父分类名（用于泛分类回退）
  final String? parentCategoryName;

  /// 为 true 时表示仅拿到开播布尔值，或需要补充网页精确分区名称。
  final bool needsDetailFallback;

  const LiveFollowStatus({
    required this.isLive,
    this.resolvedRoomId,
    this.online,
    this.categoryName,
    this.showTime,
    this.title,
    this.categoryId,
    this.parentCategoryName,
    this.needsDetailFallback = false,
  });
}
