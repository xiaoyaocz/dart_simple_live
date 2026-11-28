# 弹幕连续输入与发送流畅度优化

## 实际修改

生产代码仅改两处，未改四个平台协议、登录数据、直连策略、播放或弹幕接收代码。

- `simple_live_app/lib/modules/live_room/danmaku_composer.dart`：鼠标/键盘获得焦点时统一调用已有准备接口。斗鱼可在输入期间预先准备认证连接；其他平台保留已有准备行为（B站 HTTP 客户端按房间复用，虎牙/抖音宿主挂载时已加载）。不是四个平台都新增网络预连接。
- 同一文件：发送时保持输入焦点并选中已提交文本，接下来的输入可直接替换为下一条；确认期间表情按钮可用。不会自动排队、并发发送或重发，忙碌期间回车不提交。
- 同一文件：草稿用编辑修订号保护，重新输入相同文本也不被旧结果清空；销毁后不再改草稿。确认期间已打开的下一条表情面板不会被成功关闭浮动输入框的逻辑移除。
- `simple_live_app/lib/services/official_danmaku_layout.dart`：同步查找发送控件时取消已有待执行扫描，防止遗留计时器累积、重复扫描 DOM。仍保留即时控件刷新和原有 120ms 布局观察合并。

测试文件：`test/danmaku_composer_test.dart`、`test/api_danmaku_panel_test.dart`、`test/official_danmaku_panel_test.dart`、`test_support/official_danmaku_layout_test.cjs`（相对 `simple_live_app/`）。

## 验证证据

- 新增 9 项 Flutter 测试；全量应用测试 **578 通过，4 跳过**。日志 `C:/Temp/danmaku-speed-final-tests.log`。
- 共同发送栏对四个平台各连续操作 12 次，共 48 次本地夹具发送；断言正文顺序、仅一条在途、新草稿保留、输入焦点和组件释放。不是公开直播间的真实发送测试。
- 输入测试包含中文 IME、忙碌回车、同文重输、结果晚于组件销毁、确认时表情选择、失败保稿、浮动输入框与其他弹窗共存。
- 新测试在修复前实际失败：焦点准备、发送后焦点、新同文草稿、销毁后晚到结果、浮动表情面板；日志 `C:/Temp/danmaku-speed-red.log`、`C:/Temp/danmaku-speed-emoji-red.log`。
- Chromium 本地夹具中，20 次同步刷新发送控件留下的扫描计时器，修改前 **20 个**，修改后 **0 个**。这是待执行扫描数量，不是发送速度提升百分比。日志 `C:/Temp/danmaku-speed-browser-red.log`、`C:/Temp/danmaku-speed-browser-final.log`。
- Chromium 四套测试：官方布局、原生可信输入、真实响应判定的协议夹具、发送意图不等于成功；未向公开直播间发送消息。
- 本次修改的 Dart 文件静态检查 **No issues found**，日志 `C:/Temp/danmaku-speed-changed-analysis.log`。全项目检查仍有 **418 条 info，0 error、0 warning**，未顺手清理原有风格问题；全量分析退出码 1，并非全项目无诊断。
- 正式 `lib/main.dart` Windows Release 编译成功。日志 `C:/Temp/danmaku-speed-release.log`。保留既有 CMake CMP0175 开发警告。
- 安装包内嵌 54 个文件全部与本次 Release 哈希一致。主 exe 时间戳可未变化；Flutter 业务代码位于重新生成的 `data/app.so`。

## 限制

真实房间发送耗时、其他观众可见性、安装后逐屏手动交互、长时间运行及真实网络下的帧耗时：**本轮未验证**。不承诺降低平台服务器确认耗时，不绕过平台冷却或限流，不降低成功判定标准。已有 4 条跳过测试未变更。

## 交付与回滚

产物目录：`E:/2/dart_simple_live-master/dist/SimpleLive-2.0.24-send-fluency-20261117`。

- `SimpleLive-2.0.24-windows-x64-setup.exe`：安装包。
- `SimpleLive-2.0.24-windows-x64-portable.zip`：完整便携程序。
- `SimpleLive-send-fluency-source-changes.zip`：本次修改文件完整内容、修改前副本、清单和回滚脚本；是增量源码包，不是整个仓库快照。

修改前备份：`C:/Temp/simplelive-send-speed-before-20261117-181525`。源码回滚可解压增量源码包后执行其中 `rollback.ps1`；仅原子还原本轮修改的 6 个原有文件，不 reset 仓库，不清除数据。回滚程序版本可使用上一版直连安装包，需正常退出软件再替换程序文件；本轮没有升级用户数据结构。
