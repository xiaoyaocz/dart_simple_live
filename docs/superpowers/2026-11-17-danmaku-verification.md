# 弹幕重构验证记录（2026-11-17）

## 根因与处理

1. 原官方栏捕获 click/Enter 后立即报告 sent，与网络结果无关。移除该路径，布局桥不再拥有发送成功语义。
2. B站、斗鱼把发送入口绑定到第二个完整直播网页，其加载失败使输入栏不可用。现在采用各自的独立 API / 已有鉴权 WebSocket 适配，账号 Cookie 仍从搜索网页登录 profile 按目标 origin 读取，发送前更新；不依赖网页 DOM 或播放器加载。
3. 抖音存在全宽 56px 与内嵌横栏尺寸冲突。调整为一个内嵌 44px 原生编辑行，保留官方节点与处理器；固定输入/表情/发送几何、单行输入、段落光标及对比度，不移动或复制 DOM。
4. 切换房间在新身份可见前同步失效旧详情；发送中的旧组件与凭证操作不能提交到新房间。平台超时/网络中断是 unknown，不是失败可安全重发，更不是成功；相同未知正文不再次提交。

## 平台协议与支持状态

| 平台 | 当前唯一发送入口 | 确认依据 | 真实验证 |
|---|---|---|---|
| B站 | POST https://api.live.bilibili.com/msg/send，form + SESSDATA/bili_jct CSRF，canonical roomId | code=0 且无屏蔽标记 | 7734200 实发一次，独立匿名接收器收到 |
| 斗鱼 | 已有网关发现/登录挑战/鉴权 STT 发送；保留长连接与心跳 | 隔离发送连接 chatres=0，或同身份同正文同事务服务端回包 | 24422 实发一次，独立匿名接收器收到 |
| 虎牙 | 可见官方原生编辑器，SDK liveui/sendMessage | 严格 iStatus=0 + tNotice 正文/频道匹配；不采信泛化的 RoomSendMessageSuccess | 用户反馈该链路原本可用；本轮没有再发送公开虎牙弹幕 |
| 抖音 | 可见官方原生编辑器，官方签名/登录态不导出 | 对应房间/正文的 /webcast/room/chat/ 响应 status_code=0 | 布局及响应关联夹具通过；未进行公开实发 |

虎牙协议核对来源：用户指定 https://www.huya.com/691406 当前 HTML 引用的 `https://a.msstatic.com/huya/main3/app/room_match_64b5d3c8.js`，以及其当前 chunk `https://a.msstatic.com/huya/main3/assets.modules-24e6950c_de1e129d.js` 中 `assets/modules/chat/chat.ts`。原 SDK 的成功事件判断还允许非零状态且空 sToast，因此不以该事件作为确认。

## 已执行

- 全应用 `flutter test --no-pub`：560 passed，2 skipped。
- `test_support/official_send_intent_test.cjs`：复现旧版点击假成功（red），重构后通过。
- `test_support/official_danmaku_session_test.cjs`：虎牙精确 SDK 回调、非零空 toast 拒绝、迟到结果、抖音响应、超时、网络异常、重复保护、未知协议、空 POST body 下查询参数关联通过。
- `test_support/official_danmaku_layout_test.cjs`：当前官方网页路径（虎牙/抖音）原生可信输入、按钮、表情滚轮、重复打开关闭、DOM 替换、不同宽度、光标、可读性、SPA 防串通过。B站/斗鱼不再走该网页 UI，其 UI/协议由 Flutter 与原生适配器测试覆盖。
- 主入口 `flutter build windows --release --no-pub --target lib/main.dart` 成功。没有把测试探针作为生产入口。
- 只读审查修复两个问题：旧 canonical room 可能残留到切房加载窗口；斗鱼超时后同文可能重新发出。回归先失败后通过。

## 实发原始结果

```text
bilibili INDEPENDENT_GUEST_RECEIVER_READY room=7734200
bilibili SEND_RESULT sent 平台已确认发送
bilibili INDEPENDENT_GUEST_RECEIVED true
douyu INDEPENDENT_GUEST_RECEIVER_READY room=24422
douyu SEND_RESULT sent 发送成功
douyu INDEPENDENT_GUEST_RECEIVED true
DONE
```

发送前先建立独立匿名接收器，接收器使用核心库接收协议而不是 UI 回显；每平台只发一次，不自动重试。这证明这两次真实投递，不等于四平台长期压力测试。

## 限制

- 用户指定抖音房间 https://live.douyin.com/6096197105 的原生实机布局探针未完成：独立 runner 在创建 WebView 时以 `0xC0000005` 退出。Windows Application/1000 确认故障模块为 `flutter_inappwebview_windows_plugin.dll`，故障偏移 `0x67519`；只读日志最后为 `douyin ENVIRONMENT_READY`，未进入网页创建回调。隐藏和可见组件探针均遇到此结果。未据此推断生产进程一定会同样崩溃，也未据夹具通过宣称该房间实机已修复。此次未改动已有的原生插件修改，运行中的用户应用未被关闭。
- 平台风控、实名/验证码、禁言与频率限制由平台决定，明确显示实际结果。
- 虎牙/抖音仍依赖官方网页组件，网站改版可能使输入区/观察协议未就绪；这种情况不报告成功。
- 本次桌面 Windows 入口改动；没有新增移动端/TV 发送入口。
- 不清理用户登录 profile，不修改正在运行的安装目录，不提交或推送仓库。

## 构建产物

- 安装包：`dist/SimpleLive-2.0.24-danmaku-refactor-20261117/SimpleLive-2.0.24-windows-x64-setup.exe`。
- SHA256：`ECC95A656A220363BCE19EBC025FE16CFCE54E7C8153944A935A0FDE1A386BFB`。
- 从安装器程序集直接读取内嵌 `SimpleLive.Payload`，全部 54 个文件逐项 SHA256 与最新主程序 Release 一致；不含探针或测试资源。构建完成不等于上述抖音原生验证阻塞已解决。
