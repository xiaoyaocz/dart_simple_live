/// 抖音在线指标手动验证工具（非自动测试：文件名不带 `_test` 后缀，
/// `dart test` 不会执行，按需手动运行）。
///
/// 背景：直播间"在线人数"位置有两个不同指标在轮流写入——
/// - HTTP `room_view_stats.display_value`：当前在线观众数（"xxx人在看"）
/// - 弹幕 RoomUserSeqMessage：`total`=当前在线、`totalUser`=累计观看用户、
///   `popularity`/`popStr`=热度值（部分房间不下发，为 0/空）
///
/// 本工具连一个真实直播间，把两路数据同时打出来供人工核对。
/// 2026-10-05 实测样本：HTTP 25685 ↔ 弹幕 total 24943~25876（当前在线）、
/// totalUser 406万 ↔ totalPvForAnchor "406.0万"（累计，格式化互证）。
///
/// 用法（在 simple_live_core 目录下）：
///   dart run test/tools/verify_online_fields.dart            # 自动找在线人数最多的直播间
///   dart run test/tools/verify_online_fields.dart <webRid>   # 指定房间
/// 监听持续到 Ctrl+C 退出。详细说明见同目录 README.md。
import 'package:simple_live_core/simple_live_core.dart';

Future<void> main(List<String> args) async {
  final site = DouyinSite();
  final String webRid;
  if (args.isNotEmpty) {
    webRid = args.first;
  } else {
    print("[DISCOVER] 未指定房间号，遍历分类找在线人数最多的直播间...");
    webRid = await _discoverBestRoom(site);
  }
  print("[DISCOVER] webRid=$webRid");

  final detail = await site.getRoomDetail(roomId: webRid);
  print(
    "[DETAIL] webRid=$webRid status=${detail.status} "
    "online(HTTP 当前在线)=${detail.online} title=${detail.title}",
  );
  if (!detail.status) {
    print("[DETAIL] 房间未开播，退出");
    return;
  }

  final danmaku = site.getDanmaku() as DouyinDanmaku;
  danmaku.onRoomUserSeqDebug = (message) {
    print(
      "[SEQ] ${DateTime.now().toIso8601String()} "
      "total(当前在线)=${message.total} "
      "totalUser(累计观看)=${message.totalUser} "
      "popularity(热度)=${message.popularity} "
      "popStr=${message.popStr} "
      "onlineForAnchor=${message.onlineUserForAnchor} "
      "totalPvForAnchor=${message.totalPvForAnchor}",
    );
  };
  danmaku.onClose = (msg) => print("[WS-CLOSE] $msg");
  await danmaku.start(detail.danmakuData);
  print("[LISTENING] 监听中，Ctrl+C 退出");
}

/// 遍历前几个分类，取在线人数最高的直播间作为样本
Future<String> _discoverBestRoom(DouyinSite site) async {
  LiveRoomItem? best;
  final categores = await site.getCategores();
  for (final cat in categores.take(6)) {
    for (final sub in cat.children.take(3)) {
      try {
        final result = await site.getCategoryRooms(sub);
        for (final item in result.items) {
          if (best == null || item.online > best.online) {
            best = item;
          }
        }
      } catch (_) {
        // 单个分类拉取失败不影响整体发现
      }
    }
  }
  if (best == null) {
    throw StateError("分类里没找到直播中的房间");
  }
  return best.roomId;
}
