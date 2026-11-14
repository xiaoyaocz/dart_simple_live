# test/tools — 手动诊断工具

按需手动运行的诊断脚本，**不参与 `dart test`**（文件名不带 `_test` 后缀）。
以下工具均需联网访问对应平台，运行目录为仓库的 `simple_live_core/`。

## verify_online_fields.dart — 抖音在线指标核对

连一个真实抖音直播间，把两路"在线人数"数据同时打出来供人工核对：

- HTTP `room_view_stats.display_value`（当前在线观众数，"xxx人在看"）
- 弹幕 `RoomUserSeqMessage` 全字段（`total`=当前在线、`totalUser`=累计观看用户、
  `popularity`/`popStr`=热度值，部分房间不下发）

**背景**：直播间"在线人数"位置由弹幕推送（约 10 秒一推）与 HTTP 轮询（10 秒一轮）
轮流写入，两路指标语义不同导致显示跳变；字段语义于 2026-10-05 实测钉死，
后续做"多指标并列展示"（讨论 #139 投票）时可直接复用本工具复核。

**用法**（Ctrl+C 退出；不指定房间号会自动遍历分类挑在线人数最高的直播间）：

```bash
dart run test/tools/verify_online_fields.dart            # 自动找房间
dart run test/tools/verify_online_fields.dart <webRid>   # 指定房间
```

**输出示例**（2026-10-05 实测，房间在线约 2.5 万）：

```
[DETAIL] webRid=114687942812 status=true online(HTTP 当前在线)=25685
[SEQ] total(当前在线)=25636 totalUser(累计观看)=4063903 popularity(热度)=0
      popStr= onlineForAnchor=2.6万 totalPvForAnchor=406.4万
```

**字段语义对照**（实测结论）：

| 字段 | 含义 | 备注 |
|---|---|---|
| HTTP `display_value` | 当前在线观众数 | 原始 JSON 含 `display_long: "x万在线观众"` |
| 弹幕 `total` | 当前在线 | 与 HTTP 同源同量级，同时刻波动 ±几百 |
| 弹幕 `totalUser` | 累计观看用户数 | 永远 ≥ 当前在线；主播端 `totalPvForAnchor` 是其格式化串 |
| 弹幕 `popularity` / `popStr` | 热度值 | 部分房间不下发（实测为 0/空），投票展示时需标注 |
| 弹幕 `onlineForAnchor` | 当前在线的主播端格式化串 | "2.6万" |

实现依赖 `DouyinDanmaku.onRoomUserSeqDebug` 诊断回调（App 内不设置，无开销）。
