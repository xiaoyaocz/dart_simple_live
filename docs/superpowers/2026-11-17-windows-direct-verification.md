# Windows 应用层直连：交付与验证

仓库：`E:\2\dart_simple_live-master`。仅修改 Windows 路由策略；不限制域名，不处理系统 VPN/TUN、路由器转发。未修改 FlClash、Windows 代理或用户/系统环境变量，也未关闭正在运行的用户软件。

## 实际网络路径与改动

| 模块 | 核对结果与实现 |
| --- | --- |
| Dart HTTP | `main.dart` 在 Flutter binding 及服务初始化之前安装 Windows 专用 HttpOverrides；新 HttpClient 的 findProxy 明确返回 DIRECT，保留正常 TLS 校验。Android 的 SystemProxyService 逻辑不改。 |
| Dio 5.11.1 | 核对实际 IOHttpClientAdapter：默认 `_createHttpClient()` 使用 dart:io HttpClient。核心库、应用请求、B站/斗鱼发送器、解析页、WebDAV 的 Dio 没有另行设置代理。全局工厂覆盖这些客户端，不需要逐处复制代理设置。 |
| http 1.6.0 / WebDAV 1.2.2 | 前者 IOClient、后者 IOHttpClientAdapter 均沿用上述 HttpClient 工厂。已测试 package:http、默认 Dio、核心库 Dio 和应用 Dio。 |
| WebSocket / web_socket_channel 3.0.3 | Dart WebSocket 和弹幕 IOWebSocketChannel 使用 Dart HTTP 握手。远程同步原本额外读取 Windows 注册表代理并覆盖 HttpClient；现在 Windows 强制 DIRECT，不读取注册表，其他平台注入代理行为保留。`danmuproxy.douyu.com` 是平台弹幕服务域名，不是应用代理设置，不做字符串误删。未发现应用网络请求在另一个 Dart isolate 中绕过该入口。 |
| WebView2 | SearchWebSession 的环境参数始终含 `--no-proxy-server`；本仓库 Windows 插件的显式环境及默认环境两处 CreateCoreWebView2EnvironmentWithOptions 都在创建前设置该参数。覆盖搜索、隐藏发送宿主、CookieManager 环境、B站内嵌登录默认环境等路径。 |
| 登录数据 | 原 search_webview / search_webview_direct 路径与记忆选择保留；该布尔值现在只选择原数据目录。网络重试保持原目录，不再切换 profile。默认环境保留 nullptr userDataFolder，即原 WebView2 默认目录；不迁移、合并或删除 Cookie。 |
| media_kit 1.2.6 / libmpv | PlayerMixin 初始化 native player 时、首个流打开之前，将实际已有的 `http-proxy` 属性置空。Android 按主机配置代理的原逻辑保留；Windows 不再设置非空值。 |
| 原生环境 | Windows runner 在创建 Flutter engine/插件前，同时清除本进程 Win32 和 CRT 中 HTTP_PROXY、HTTPS_PROXY、ALL_PROXY、FTP_PROXY、SOCKS_PROXY、SOCKS5_PROXY、NO_PROXY 及小写形式。子进程继承清理后的环境，不写注册表或持久环境。 |
| 安装/快捷方式 | 既有安装器内嵌完整 Release，快捷方式 TargetPath 直接指向 simple_live_app.exe；未增加启动脚本、VBS、后台守护程序或手工参数。 |

## 修改文件

以下路径均相对于上述仓库：

- `simple_live_app/lib/main.dart`：最早安装 Windows DIRECT 工厂。
- `simple_live_app/lib/services/windows_direct_network.dart`：新增 Windows HttpOverrides。
- `simple_live_app/windows/runner/main.cpp`、`windows/runner/direct_network.h`（同属 simple_live_app）：原生启动前清理进程环境。
- `simple_live_app/lib/modules/live_room/player/player_controller.dart`：初始化 mpv 禁用 HTTP 代理。
- `simple_live_app/lib/services/remote_sync_connection.dart`：Windows 同步连接强制 DIRECT，移除 Windows 注册表代理读取。
- `simple_live_app/lib/services/search_web_session.dart`：保留 profile，始终传入直连参数。
- `simple_live_app/lib/modules/search/search_controller.dart`：网络重试不切换登录目录。
- `simple_live_app/packages/flutter_inappwebview_windows/windows/webview_environment/webview_environment.cpp`：显式/默认管理环境的创建参数。
- `simple_live_app/packages/flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp`：未指定环境的网页创建参数。
- 回归：`test/windows_direct_network_test.dart`、`test/remote_sync_connection_test.dart`、`test/search_webview_startup_test.dart`、`test/search_danmaku_credentials_test.dart`（均在 simple_live_app 下）。旧 Cookie 测试改为依据真实 userDataFolder 区分 profile，不再把代理标志当作 profile 身份。
- 诊断源码：`simple_live_app/test_support/windows_direct_network_probe.dart`、`windows_direct_environment_test.cpp`（同一 test_support 目录）。不由主入口引用，不进入安装程序运行链。

## 测试与实际连接

### 自动化 / 构建

- 完整应用：569 passed / 4 skipped，`C:\Temp\windows-direct-corrected-tests.log`。其中两条旧的代理注入测试仅适用于非 Windows，另两条为原有跳过项。
- DIRECT 回归：给 HttpOverrides 注入本机错误代理后，普通 HttpClient、package:http、默认/核心/应用 Dio、WebSocket 和远程同步均直达本地源服务器，测试代理命中 0。
- profile 回归先失败再通过：默认与重试都含直连参数，userDataFolder 保持相同；既有账号选择、注销和不合并 Cookie 的测试通过。
- 原生 C++ 环境测试编译并执行通过：Win32/CRT 变量均不存在，父进程环境值保持不变。
- Dart 相关文件分析：0 error、0 warning，诊断探针有1条花括号风格 info。`C:\Temp\windows-direct-verified-analysis.log`。
- 真实主入口 Release 构建通过：`C:\Temp\windows-direct-delivery-release.log`。CMake CMP0175 和 WebView2 SDK 头文件 C4458 警告保留。

### 实网原生探针（不是安装版逐屏验收）

使用真实 Flutter Windows runner、相同进程环境清理函数、相同 Dart 网络策略、本仓库 WebView2 插件及 libmpv。浏览器数据采用临时目录或诊断程序自己的默认目录，未操作用户登录数据。记录：`C:\Temp\windows-direct-r3-integration.log`。

| 验证项 | 实际结果 |
| --- | --- |
| 首页推荐接口 | 虎牙真实返回120项 |
| 搜索接口 | 虎牙关键词搜索真实返回20项 |
| 房间详情 | 虎牙546540返回正在直播 |
| 弹幕接收 | WebSocket open 后收到1条聊天、1条在线更新 |
| 直播播放 | 使用 VideoController 实际打开流，videoWidth=800、位置9233ms，mpv http-proxy 读回为空 |
| 搜索网页 | 显式环境加载 www.huya.com，DOMContentLoaded，存在标题 |
| 登录网页 | 默认环境加载 passport.bilibili.com，DOMContentLoaded，存在标题 |
| 完整账号登录/验证码 | **未验证**：未输入或读取账号凭据 |
| 弹幕公开发送 | **未验证**：本轮没有发送公开消息 |
| 安装版逐屏主页/搜索操作、所有平台、长期卡顿/流畅度 | **未验证**：未终止或替换用户当前运行的旧版本，未把探针当作安装版完整验收 |

### TCP 与进程环境证据

- 启动探针时专门注入错误的 HTTP/HTTPS/ALL/SOCKS 代理，指向本机临时监听器。进程报告代理环境变量不存在，监听器命中0。
- 首轮连接审计确实发现默认登录网页的一条 WebView2 子进程到127.0.0.1:7890的连接；未把单独搜索网页通过当作全部完成。修正默认环境创建后重新运行。
- 最后一次观测约50.8秒：探针主进程 PID19856、两个 WebView2 浏览器根进程 PID26112/21096，二者实际命令行均有 no-proxy-server；renderer/GPU 子进程无需重复该命令行标志。
- 最后一次采样观察到46个远端端点，未观察到主进程及相关子进程连接已识别的本机 FlClash 监听端口1053/7890或测试代理端口；`TRAP_HITS 0`、`KNOWN_LOCAL_PROXY_CONNECTIONS 0`。
- 系统代理前后比较 `SYSTEM_PROXY_UNCHANGED True`。FlClash/FlClashCore 仍为原PID17544/18376。记录：`C:\Temp\windows-direct-r3-connections.log`。
- 这是指定观测窗口的实际 TCP 检查，不是所有将来连接、所有系统 VPN/TUN 或网络转发的保证。

## 交付产物

目录：`E:\2\dart_simple_live-master\dist\SimpleLive-2.0.24-direct-20261117`。

- 安装包：`SimpleLive-2.0.24-windows-x64-setup.exe`
  - SHA256：`638AC1253673E2CB8200A400045F849202B859C1C537BDE63053EC237980CA91`
- 可运行便携程序：`SimpleLive-2.0.24-windows-x64-portable.zip`
  - SHA256：`998B2F051EC4B1465F041D36F253A28A3A05A8C0C8C0B0142AB4E02010D10C25`
- 改动源码包：`SimpleLive-windows-direct-source.zip`；source 为本轮文件，before 为修改前备份，manifest.json 列出原有/新增文件及哈希。它是当前仓库的改动包，不是独立完整 Flutter 项目。
- 已直接读取安装包内嵌 SimpleLive.Payload：54/54文件哈希与本轮 Release 一致。没有将探针二进制或临时入口打包成主程序。

## 回滚

修改前备份：`C:\Temp\simplelive-direct-before-20261117-174354`；源码包也包含实际修改的原有文件备份。

1. 退出 SimpleLive。程序回滚可重新安装上一份 `SimpleLive-2.0.24-readiness-handshake-r2-20261117` 安装包，沿用原安装目录；不删除用户数据目录。
2. 源码回滚：按 manifest.json 的 originalFiles，将 before 中对应文件恢复到仓库相同相对路径；不要重置整个仓库。只在确认没有后续编辑后，移除 manifest.json 中本轮新增的源文件。保留所有不在清单中的文件。
3. 重新使用原项目的 Flutter Windows 构建命令编译。恢复原 main.dart/main.cpp 后，新增的未引用诊断文件即使保留也不会进入主程序。

本轮未尝试以“直连”结论替代抖音弹幕真实投递或之前卡顿问题的验收。
