# simple_live_core 测试

## 自动测试

`dart test` 运行本目录下所有 `*_test.dart`，均为离线或模拟数据，
覆盖：弹幕解析、站点解析（抖音/斗鱼/快手/虎牙/B站）、Cookie 脱敏
（HttpLogSanitizer）、斗鱼 Passport（JWT 过期判定/Set-Cookie 提取）、
关注刷新范围、清晰度记忆等。

## 手动诊断工具

`tools/` 子目录存放需要联网、按需手动运行的诊断脚本，
`dart test` **不会**执行它们。使用说明见
[tools/README.md](tools/README.md)：

- `tools/verify_online_fields.dart` — 抖音在线指标核对（当前在线/累计观看/热度）
