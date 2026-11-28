# 四平台统一输入栏与本人高亮：验证记录

## 本轮实现

- Windows 虎牙、抖音改为与 B站、斗鱼相同的 Flutter DanmakuComposer 和状态行；输入、表情、Enter/输入法、单次提交、失败保留草稿复用同一组件。
- B站、斗鱼保留独立发送适配。虎牙、抖音官方网页仅作为不可见协议宿主，复用原登录 profile 和官方提交处理器；通过 CDP 可信输入/点击，不请求 Windows 键盘焦点。宿主排除指针、语义及焦点遍历。网页错误通过共同状态行返回，重连不自动重发正文。
- 虎牙表情发送继续调用 RoomEmoticons.encodeForSend，草稿保留原展示标签。
- 四平台接收消息保留字符串 UID，包含抖音独立表情事件。本人匹配优先 UID，仅无 UID 时使用已确认完整昵称；删除相同正文推断本人身份的路径。昵称更新不丢弃已确认 UID，切房或登录失效清除身份。
- 聊天列表和浮动弹幕使用同一身份判断。接收先于身份确认时，列表刷新，既有浮动弹幕只重建变化的缓存图像/表情位置，不重放、不改变位置和剩余时长；暂停时也刷新。扫描复杂度为 O(当前屏幕弹幕数)，仅身份变化触发。

## 已执行验证

- 全应用 `flutter test --no-pub --reporter expanded`：566 passed / 2 skipped。日志 `C:\Temp\unified-full-tests-final.log`。
- 核心库确定性测试：101 passed；排除有真实长连接网络依赖的 `simple_live_core_test.dart`。日志 `C:\Temp\unified-core-tests.log`。
- 新增/调整覆盖：四平台相同身份规则、同名不同 UID、相同正文不猜本人、登录清除、切房清除、接收先于确认的刷新、暂停浮动弹幕缓存重建、隐藏网页不抢焦点/点击/布局、虎牙表情编码及失败草稿、原生提交后的 SDK 确认。
- 旧网页浮层几何测试由共享 Flutter 栏和隐藏宿主隔离测试替代；独立官方宿主生命周期测试保留。测试数量变化包含这些替换，并非忽略旧断言。
- 本地 Chromium：`official_composer_input_test.cjs`（textarea/contenteditable、替换旧草稿、可信事件、禁用不提交）、`official_danmaku_session_test.cjs`、`official_send_intent_test.cjs`、`official_danmaku_layout_test.cjs` 全部通过。夹具不访问公开直播间，也不等于实发验收。
- 本轮只读审查提出并修复：隐藏宿主仍能请求焦点、虎牙编码遗漏、迟到身份不能更新浮动弹幕、昵称变化丢失 UID；对应回归通过。
- 静态分析：修改入口无 error/warning，8 条花括号风格 info 未扩大整理。
- 主入口 `flutter build windows --release --no-pub --target lib/main.dart` 成功；既有插件 CMake CMP0175 开发警告仍在。

## 产物

- `E:\2\dart_simple_live-master\dist\SimpleLive-2.0.24-unified-composer-20261117\SimpleLive-2.0.24-windows-x64-setup.exe`
- SHA256：`A7D9A5187CFD147B2260B915DD0E85DC0EC5C3078A71815BC281029E38E49730`
- 读取安装器内嵌 SimpleLive.Payload，54/54 文件逐项 SHA256 与主入口 Release 一致，无探针资源。

## 验收边界

- 本轮未再发送公开测试弹幕。B站 7734200、斗鱼 24422 的真实发送/独立接收记录来自上一轮，见 `2026-11-17-danmaku-verification.md`，不是本轮隐藏宿主实测。
- 虎牙/抖音新隐藏宿主在真实房间的端到端实发尚未完成。此前独立原生探针遇到 WebView 插件 `0xC0000005` 崩溃，本轮未声称解决该原生问题，也未以本地夹具替代原生实机验证。
- 身份尚未确认时不猜测本人。无 UID 时完整昵称兜底仍存在平台同名限制；有 UID 时不会用昵称覆盖 UID 判定。
- 本轮统一发送入口限 Windows；未新增移动端或 TV 入口。运行中的已安装应用及登录 profile 未覆盖、未关闭，仓库未提交推送。
