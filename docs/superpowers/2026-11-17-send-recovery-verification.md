# 统一栏发送恢复及 B站表情尺寸

## 复现与根因

1. 用户截图：虎牙、抖音共同输入栏提示“平台发送区尚未就绪”。独立原生 runner 确定性复现启动后 `0xC0000005`。Debug 符号栈定位到 `in_app_webview.cpp` JavaScript handler 的 defaultBehaviour：`optional<const EncodableValue*>` 有值但内部指针为 nullptr，调用 IsNull 崩溃。修复前日志 `C:\Temp\readiness-repro-debug.log`、`C:\Temp\readiness-native-stack.log`；增加内部指针检查后，同一原生探针不再崩溃，生产的 ExcludeFocus/IgnorePointer/Opacity(0) 宿主两平台均进入 ready（`C:\Temp\production-host-readiness.log`）。未把去掉隐藏或伪装 ready 当作修复。
2. 抖音官方 editor-kit 实际 DOM 在 `ace-line` 末尾包含 `span[data-enter="true"][data-leaf="true"]`，内容 U+200B。Input.insertText 正常输入后 raw textContent 与草稿不同。只排除抖音该结构叶子的独立 U+200B，其他用户输入不改；校验与 click/Enter 事务正文共用读取方法。
3. 实际抖音 `#chatInput.webcast-chatroom___input-container` 中，`.webcast-chatroom___emoji-icon` 在编辑器之前，`.webcast-chatroom___send-btn` SVG 在编辑器之后。旧“输入后第一个 SVG 是表情”的假设把发送箭头误标成表情，composerButton 为空。按真实 DOM 独立识别两控件，提交前同步发现新控件，消除 120ms 观察器防抖窗口。
4. B站图片原先被 IconButton 的方形小尺寸限制。表情目录为 B站或含横向表情时采用 2–4 列、64 高格子，图像 BoxFit.contain，不拉伸；缺少宽高元数据的 B站表情也使用大格子。其他平台常规小表情保持密集网格。输入、发送协议、原 UI 配色不变。
5. 共同状态行现在显示宿主连接就绪、启动失败或需要登录/验证，不再隐藏网页的连接状态。

## 测试

- 应用：`flutter test --no-pub --reporter expanded`，568 passed / 2 skipped，`C:\Temp\send-recovery-final-tests.log`。
- 本地 Chromium 四组测试通过：official_danmaku_layout_test、official_composer_input_test、official_danmaku_session_test、official_send_intent_test。
- 新回归先失败再通过：原生 null handler 崩溃；真实 editor-kit 哨兵正文；原生动态创建发送按钮；抖音“表情在前、发送 SVG 在后”的真实 DOM；B站横向及缺尺寸元数据的表情大格子。小窗口滚动、点击选中仍通过。
- 只读审查确认原生指针判断、结构标记精确排除、实际控件选择、同步控件发现及 B站尺寸处理无新增重大问题。
- 静态分析无 error/warning，9 条花括号风格 info 保留。
- 主入口 Release 构建通过：`flutter build windows --release --no-pub --target lib/main.dart`。既有 CMake CMP0175 开发警告保留。

## 真实发送验收与边界

使用 `test_support/official_composer_native_probe.dart`，与生产相同的隐藏官方宿主和 OfficialComposerTransport。每次发送前建立独立匿名接收器；不打印 Cookie，不自动重发。测试内容同时含文字和平台表情 token。

- 虎牙 691406：生产隐藏宿主 ready，实际 SDK iStatus=0、频道/正文一致的 tNotice，返回 sent。独立匿名接收器 15 秒内未收到该测试消息。记录 `C:\Temp\native-composer-live-result.log`。
- 抖音 6096197105：先复现“完整草稿校验失败”（未提交）；修复哨兵后出现 unknown（未自动重发同文）；查明发送按钮误识别后，实际 /webcast/room/chat/ 对应正文/房间响应 status_code=0，返回 sent。独立匿名接收器 15 秒内未收到该测试消息。记录 `C:\Temp\douyin-correct-button-live.log`。
- 因此可以确认两个平台已真实发起请求并获得平台确认；不能把这当作“其他观众可见”或长期稳定验收通过。接收器订阅时序、平台审核/分发等原因尚未定位，未声称具体是哪一种。
- 本轮未再向 B站、斗鱼发公开消息，二者发送协议不改。B站表情比例由布局回归验证，未以本轮测试冒充 B站实发验收。
- 运行中的用户应用和 profile 未关闭、覆盖或清理；诊断 runner 位于独立临时项目，未打包进主程序。未提交或推送仓库。

## 安装包

- `E:\2\dart_simple_live-master\dist\SimpleLive-2.0.24-send-recovery-20261117\SimpleLive-2.0.24-windows-x64-setup.exe`
- SHA256：`E28A54B423B6CB3659C3FD45A37324763AEC3087FFFBC139252ECECE8B5DF8BA`
- 内嵌 SimpleLive.Payload 54/54 文件 SHA256 与最新主入口 Release 一致，无探针资源。

## 继续核验：官方连接就绪与独立订阅屏障（最新结果）

本节覆盖上文旧安装包和旧接收器时序的结论，不将平台 ACK 等同公开投递。

- 独立接收探针确认：虎牙 691406 正在直播，正常收到已解析聊天及在线数据；抖音 6096197105 当前接口报告下播。抖音下播目标不再提交测试消息，已请求新的正在直播的房间，等待用户提供。
- 旧探针仅等 WebSocket open，早于订阅完成。新探针必须先收到已解析 chat/online 才允许单次发送；无流量或下播不发。不会自动重发未知结果。
- 修复虎牙 DOM ready 早于 SDK hook ready 的竞态：共享输入区必须等待协议 ready，并显示加载组件/等待官方连接状态；连接成功时即使没有 DOM mutation 也重新检查布局。
- 审查发现旧 webpack 观察方式会在网站主入口之前提前 require TTP；重复使用同一 chunk ID 也不能发现延迟模块。根据实际发布源 `const _=window.TTP=g`，现在只轮询网站自行初始化后公开的 window.TTP，注册与官方 chat 相同的 TTP.ready。没有主动 require 模块，也没有以更早的 initComplete 代替 ready。
- 回归先红后绿：夹具只公开真实的 window.TTP，并禁止 webpack 注入；初始未公开对象和 SDK callback 尚未执行时均不就绪，延迟 callback 执行后才接受发送。
- 原生只读检查通过：`C:\Temp\huya-public-ttp-readiness.log`，生产相同隐藏宿主获得 SDK ready 后进入 ready。
- 原生单次实发：`C:\Temp\huya-public-ttp-send.log`。虎牙独立匿名接收器发送前收到 chat=1；发送文字加表情 token 后 SDK 确认 sent；其后15秒内独立接收未匹配测试消息，同时收到其他 chat，最终 chat=6、online=1。因此“其他观众可见”验收仍未通过，根因尚未确认。不继续猜测/修改接收协议，也不自动重复公开提交。

### 最新自动化和构建

- 应用完整测试：568 passed / 2 skipped，`C:\Temp\send-recovery-public-ttp-tests.log`。
- Chromium：official_danmaku_session_test、official_danmaku_layout_test、official_composer_input_test、official_send_intent_test 全部通过。这些是本地回归夹具，不是真实投递证据。
- 相关源及探针静态分析：0 error / 0 warning，9条 info（8条花括号风格、1条诊断探针对传递依赖 tars_dart 的引用），`C:\Temp\send-recovery-public-ttp-analysis.log`。
- 主入口 Release 构建通过，`C:\Temp\send-recovery-public-ttp-release.log`；既有 CMake CMP0175 开发警告保留。
- 新安装包（未覆盖旧包）：`E:\2\dart_simple_live-master\dist\SimpleLive-2.0.24-send-recovery-public-ttp-20261117\SimpleLive-2.0.24-windows-x64-setup.exe`。
- SHA256：`4FDEA10B64F1BF66E27DD97B85D898419A070138158D126E513B59B70C63AFA5`。
- 实际读取安装包内嵌 SimpleLive.Payload，54/54文件哈希与该次主入口 Release 一致。
- B站放大表情改动包含在新包，保持比例；B站/斗鱼本轮未做新的公开发送，原发送协议未改。抖音结构标记/按钮修复保留，正在直播房间的新实发尚未验证。
## 新房间复测与提交握手修复（用户再次反馈后）

目标：虎牙 546540、抖音 580056875446。核对用户正在运行目录的 app.so 和 Windows WebView DLL，与上轮 Release 哈希一致；不是凭猜测归因“未更新”。未关闭或改写用户运行中的应用。

### 本轮定位与生产改动

1. 新增 `test_support/api_composer_native_probe.dart`，挂载真正的 ApiDanmakuPanel，在300宽、底部 Column/Stack 布局下运行，而非只挂载 OfficialDanmakuPanel。--check 不发消息；--send 必须先收到独立接收器解码的房间流量，且每平台只提交一次。
2. 虎牙初始化有明显波动：同房间有的启动在65秒内仍停在 SDK 等待阶段，有的启动正常 ready。只读诊断确认 ready 时真实 TTP.ready/initComplete 均完成，SDK 中有非零用户标识。不能据此推断账号没有登录或具体网络端点故障。临时 WebSocket/错误监听已从测试支持文件移除，没有打包进产品。
3. 修复确定性的前置状态错误：Dart 的 _layoutStatus/_error 镜像尚未更新或20秒UI期限过后，即使当前网页实际已就绪，旧实现仍拒绝发送；有 _error 时还会先 reload，拆掉已经可用/正在连接的页面。现在对已存在的页面统一交给实际提交桥检查当前 editor 和协议状态，不依据过时镜像先行拒绝，也不在发送按钮上重载已有页面。环境创建失败、根本没有原生页面时，仍保留只重建连接、不自动发送的恢复路径。
4. 提交桥在任何草稿编辑或点击前最多等待当前页面就绪12秒；Dart 对整个编辑/点击过程设18秒上限。真正未就绪时明确提示官方连接/发送组件仍在加载、本次未提交。等待阶段已有 single-flight 锁；结果不明时仍禁止同文自动重发。
5. 先红后绿：已连接页面但Flutter镜像仍loading/已过deadline；短暂未就绪后原生输入/点击；永久未就绪零编辑零点击；环境失败后恢复且零提交。没有把 ready 或本地输入视作平台成功。

### 新房间实际结果与未完成项

- `C:\Temp\actual-api-new-rooms-send.log`：两个新房间均从真正 ApiDanmakuPanel 的宿主得到 sent/平台确认；虎牙独立匿名接收仍未匹配测试消息（期间其他聊天38条），抖音仍未匹配（收到在线帧、未收到chat）。该轮发生于本次状态握手修复之前。
- `C:\Temp\actual-api-current-readiness-send.log`：新版等待逻辑下，虎牙一次启动65秒仍未 ready，探针没有提交；抖音通过真实 ApiDanmakuPanel.send 输入文字和表情token，得到平台确认，独立匿名接收未匹配。没有重复提交未知结果。
- 独立无登录 Chrome 官方网页观察：`C:\Temp\official-guest-new-rooms.log`。发送前目标短句不存在，观察期未匹配测试短句。此观察器未建立“已经收到公开聊天”的严格订阅屏障，因此仅记录未观察到，不能当作平台确实屏蔽或所有观众都不可见的证明。
- `C:\Temp\sdk-account-readonly.log`：虎牙真实SDK连接及非零用户标识确认；未公开账号ID、Cookie或凭据。
- “其他观众可见、两平台连续稳定发送”仍未验收通过。本轮没有将 ACK 或本地HTML回归冒充最终验收。已异步询问用户同一搜索网页的原生发送能否被另一端看到，用于区分账号/平台限制与桥接问题，等待答复。
- B站/斗鱼发送协议、播放和接收协议本轮均未修改。

### 最新验证与产物

- 完整应用测试：570 passed / 2 skipped，`C:\Temp\current-readiness-final-tests.log`。
- 四组 Chromium 回归通过，包括新增延迟就绪、就绪超时不编辑/不提交的检查。
- 相关源码/测试支持分析：0 error、0 warning、6条花括号风格info，`C:\Temp\current-readiness-final-analysis.log`。
- 主入口 Release 构建通过：`C:\Temp\current-readiness-final-release.log`。保留既有 CMake CMP0175 开发警告。
- 最终本轮包：`E:\2\dart_simple_live-master\dist\SimpleLive-2.0.24-readiness-handshake-r2-20261117\SimpleLive-2.0.24-windows-x64-setup.exe`。
- SHA256：`0F4A28863A2F69C1DE376D46D5790515745E8F0CDD73185663B3F5BA8F7B54F8`。
- 实际读取包内嵌 SimpleLive.Payload：54/54文件哈希与本次主入口 Release 完全一致。旧包未覆盖。