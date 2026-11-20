# Simple Live 贡献指南

> 从 clone 仓库到提交 PR，用 AI 开发你想要的功能，自己是最懂自己的。
>
> 本文面向没有 Flutter 经验、但愿意动手的用户：讲清楚环境怎么装、代码怎么跑、怎么让豆包 / DeepSeek 这类 AI 帮你写代码、最后怎么把改动合并进官方仓库。
>
> 当然更强的 AI 模型会更好，但是写一些简单的小需求、小功能、UI小改动，不用用到 `Claude Fable5.2` 这种超级模型。

## 写在前面

Simple Live 的功能已经比较完善，用户量也不小，我不可能把每个人提的需求都做一遍。

> [!IMPORTANT]
>
> 但项目完全开放 PR：你自己把功能做出来、提交合并申请，是最主动、最快的路径。但是不是什么PR都值得合并的，一些小功能，你可以自己构建了自己使用都是完全可以的，比如你开发自己的fork分支。
>
> 注意项目的 [License](https://github.com/June6699/dart_simple_live/blob/master/LICENSE) 是 GPL 3.0，大致内容如下。
>
> - 任何人都能免费使用、fork、修改、再分发（本项目本身就是从[上游](https://github.com/xiaoyaocz/dart_simple_live) fork 来的）。
> - 但发布修改版 / 衍生 App 时，必须同样用 GPL 3.0 开源全部源码，不能闭源、不能据为己有。
> - 提交 PR 即表示贡献者同意其代码在 GPL 3.0 下发布。
> - 可以收费分发，但无法阻止别人自由复制和再分发。

对于同样一个需求，我排期上线的优先级大致是这样：

1、优秀的PR

2、赞助用户提的需求

2、GitHub Discussions 里的 Ideas 帖（Upvote / 👍 达标）

- 注意，目前为止，没有一个曾经的需求是达过标的，大多都是个人诉求
- 也有可能是因为项目刚开始需求众多，但是现在项目已大幅稳定，对于需求的审核需要更加严格一些

4、QQ 群 / 微信里直接反馈的需求

关于 AI 能做什么：

- **小功能、UI 调整、非大厂平台的添加**：豆包 2.1 pro、deepsee-v4.1-flash-1017 这个级别的模型完全能胜任，而且便宜、有免费额度。
- **大厂平台**（抖音、快手这类有签名和风控的）：让 AI 盲猜接口容易翻车，正确做法是参考 README 里列出的已知开源项目（比如 `wbt5/real-url`、`YunzhiYike/douyin-live`），让 AI 把里面的 Python / JavaScript 逻辑翻译成 Dart。
- 模型只是模型，会用一个就会用别的。本文以豆包 2.1 pro 和 DeepSeek（用户基数大、使用广泛）为例，不做工具使用教程，其他模型同理。

> [!IMPORTANT]
> 不是所有 PR 都会被合并。提交前请务必读完[第十节的红线清单](#10-红线这些-pr-不会被合并)：碰账号、碰钱、碰写操作、碰官方活动的功能，一律不会合并。
>
> 另外破解付费房间的 PR 也不会被合并。

---

## 目录

1. [先认识这个仓库](#1-先认识这个仓库)
2. [准备开发环境](#2-准备开发环境)
3. [Fork、Clone 与首次运行](#3-forkclone-与首次运行)
4. [代码地图](#4-代码地图)
5. [用 AI 开发功能的正确姿势](#5-用-ai-开发功能的正确姿势)
6. [实战：给听直播页加一个音量滑块](#6-实战给听直播页加一个音量滑块)
7. [新增直播平台 checklist](#7-新增直播平台-checklist)
8. [构建与验证](#8-构建与验证)
9. [提交 PR](#9-提交-pr)
10. [红线：这些 PR 不会被合并](#10-红线这些-pr-不会被合并)
11. [沟通渠道](#11-沟通渠道)

---

## 1. 先认识这个仓库

仓库根目录下有四个子工程，外加一个第三方依赖目录：

| 目录 | 是什么 | 你需要知道的 |
|------|--------|--------------|
| `simple_live_app/` | 主 App | Android、iOS、Windows、macOS、Linux 共用一套 Dart 代码 |
| `simple_live_tv_app/` | TV App | Android TV、TV-Windows（TV 界面跑在桌面端），独立 UI，与主 App 不共享页面代码 |
| `simple_live_core/` | 核心共享库 | 五个直播平台的取流、搜索、弹幕、接口实现，两个 App 都依赖它 |
| `simple_live_console/` | 弹幕姬控制台 | 独立的命令行小工具，日常开发基本不用动 |
| `third_party/` | 第三方路径依赖 | 弹幕库、media_kit 补丁等，已经包含在仓库里，**不要删、不要替换** |

**最重要的一个认知：主 App 和 TV App 是"复制修改"式并行的。** 同一个功能经常在两个工程里各有一份同名文件（比如两边都有 `live_room_controller.dart`、`sites.dart`），但它们是两个完全独立的文件。

所以每次改完代码都要问自己一句：**这个改动 TV 端要不要同步？** 让 AI 干活时也要明确告诉它改的是哪个平台，有些功能比如弹幕屏蔽肯定全平台都要有，浏览器登录这种肯定上不了TV，因为电视就没有浏览器这个东西（如果你家电视真这么牛逼当我没说）。

技术栈：

- **Flutter / Dart**：界面和业务语言
- **GetX（get 包）**：状态管理、路由、依赖注入
- **Hive**：本地数据库，存关注、历史、设置
- **media_kit（libmpv）**：视频播放器内核
- **dio**：HTTP 网络请求

---

## 2. 准备开发环境

### 2.1 工具清单

先分清哪些是通用必装、哪些只跟目标平台有关，避免装一堆用不上的东西。

**第一类：不管开发什么平台都必须装的（3 个）**

| 工具 | 版本要求 | 用来干什么 |
|------|----------|------------|
| Git | 任意较新版本 | 拉代码、提交、推送 |
| Flutter SDK | **3.41.9 stable（必须这个版本）** | 整个项目的开发框架 |
| IDE | VS Code 或 Android Studio，二选一 | 写代码、跑调试 |

**第二类：按目标平台安装，互不相关**：注意如果你想构建应用出来使用的话，就要安装，否则不用。

| 目标平台 | JDK 17 | Android SDK | Visual Studio 2022（C++ 桌面工作负载） | Xcode | 备注 |
|----------|---------|-------------|------------------------------------------|-------|------|
| Android 手机 App | 必须 | 必须 | 不需要 | 不需要 | 装 Android Studio 一次带齐 JDK + SDK，最省事 |
| Android TV | 必须 | 必须 | 不需要 | 不需要 | 同上，只是工程是 `simple_live_tv_app` |
| Windows 桌面 | 不需要 | 不需要 | 必须 | 不需要 | 可以完全不碰 JDK / Android SDK |
| TV-Windows | 不需要 | 不需要 | 必须 | 不需要 | 同上 |
| macOS | 不需要 | 不需要 | 不需要 | 必须 | 只能在 Mac 上构建，一般走 GitHub Actions |
| iOS | 不需要 | 不需要 | 不需要 | 必须 | 同上，还需完整 Xcode 工具链 |
| Linux 桌面 | 不需要 | 不需要 | 不需要 | 不需要 | 需 Linux 本机的 clang / cmake / ninja 等系统依赖，一般走 Actions |

几个关键认知：

1. **JDK 不是通用必装项**，只在做 Android / TV 时需要，认准 17；装 Android Studio 会自带，不用单独折腾。
2. **只做 Windows 桌面的人，JDK 和 Android SDK 一个都不用装**，但必须装 Visual Studio 2022 并勾选"使用 C++ 的桌面开发"（含 CMake、MSBuild），注意它不是 VS Code。
3. mac / iOS / Linux 普通贡献者不用自己搭环境，仓库的 Actions 手动 workflow 会构建，本地用 Android 或 Windows 验证功能即可。

### 2.2 安装 Git

- Windows：去 [git-scm.com](https://git-scm.com/download/win) 下载安装包，安装选项一路默认即可。
- macOS：终端执行 `xcode-select --install`，或用 Homebrew：`brew install git`。
- Linux：`sudo apt install git`（Ubuntu / Debian）。

装完在终端验证：

```bash
git --version
```

### 2.3 安装 Flutter（版本必须对齐）

> [!WARNING]
> **请安装 Flutter 3.41.9 stable，不要直接下官网首页的最新版。** 我本地和 GitHub Actions 全部固定在 3.41.9，版本不一致可能出现别人那能编译、你这编译不过的情况，PR 也无法对齐。
>
> 而且 flutter 版本是限制可使用系统版本最重要的因素之一。
>
> 唯一的例外：如果你的目标是让功能适配更老的安卓手机、需要验证低版本兼容性，才使用更低版本的 Flutter，并且要在 PR 里说明。
>
> - 可以考虑单独开一个低版本 Flutter 做的仓库，但是那对于我这种小项目可能也没啥必要，没有那么多的低系统版本用户。

安装方式二选一：

**方式 A：手动安装（推荐）**

1. 打开 Flutter SDK 归档页：[docs.flutter.dev/release/archive](https://docs.flutter.dev/release/archive)（国内可访问中文镜像 [flutter.cn/docs/release/archive](https://flutter.cn/docs/release/archive)）。
2. 找到 **3.41.9 stable**，下载对应系统的压缩包。
3. 解压到一个**路径不含中文和空格**的目录，比如 Windows 下 `D:\\flutter`、macOS / Linux 下 `/data//flutter`。
4. 把解压目录下的 `bin` 目录加入系统环境变量 `PATH`，以便你在终端就能直接使用 flutter 调用命令。

**方式 B：用 FVM 管理版本（如果你电脑有别的项目的必须使用的flutter版本，不是3.41.9 stable版本）**

安装 FVM 后，在仓库根目录执行：

```bash
fvm install 3.41.9
fvm use 3.41.9
```

之后所有 flutter 命令写成 `fvm flutter <命令>`，IDE 也有对应的 FVM 插件。

装完后新开一个终端，验证版本：

```bash
flutter --version
```

确认输出的版本号是 3.41.9，然后执行体检命令：

```bash
flutter doctor
```

`flutter doctor` 会逐项告诉你还缺什么（Android 许可没接受、VS 没装等等），按提示处理。Android 许可证需要执行：

```bash
flutter doctor --android-licenses
```

全部输入 `y` 接受。

### 2.4 JDK 17 与 Android SDK

最省事的方式是直接安装 **Android Studio**：[developer.android.com/studio](https://developer.android.com/studio)，安装向导会自带 JDK、Android SDK、模拟器和平台工具。

装完后在 Android Studio 的 SDK Manager 里确认：

- 已安装一个较新的 Android Platform（API 34 以上即可）
- 已安装 Android SDK Command-line Tools、Platform-Tools、Build-Tools

如果你单独装 JDK，注意必须是 **JDK 17**，并设置好 `JAVA_HOME` 环境变量指向 JDK 17 的安装目录。Gradle 用更高或更低版本的 JDK 都可能报错。

### 2.5 IDE 选择

- **VS Code**：轻量，安装 Flutter 插件后即可开发，适合电脑配置一般的用户。
- **Android Studio（基于 IntelliJ）**：自带模拟器管理、Gradle 集成，做 Android 相关功能更顺手。

两个都能用，选你看着顺眼的。无论哪个，装好后都要安装 Flutter / Dart 插件。

### 2.6 Windows 桌面构建的额外要求

如果你想在 Windows 上构建桌面版（而不只是 Android），还需要：

1. 安装 **Visual Studio 2022**（社区版免费，注意不是 Visual Studio Code），勾选工作负载 **"使用 C++ 的桌面开发"**，里面包含 CMake 和 MSBuild。
2. 首次 Windows 构建时，media_kit 会从 GitHub 下载 ANGLE、libmpv 等原生归档，见下一节的网络说明。

只做 Android 开发的话，可以跳过这一步。

### 2.7 国内网络与代理

**国内镜像（建议所有国内用户配置）**

Flutter 默认从 Google 的服务器拉资源，国内需要换成官方镜像。设置两个环境变量：

Windows（PowerShell，永久生效）：

```powershell
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "User")
```

macOS / Linux（写进 `~/.bashrc` 或 `~/.zshrc`）：

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn
```

**代理的基本规则**

如果你有代理工具，记住下面几条原则，能避开绝大多数网络怪问题：

1. **默认直连优先**：Dart 包镜像（`pub.flutter-io.cn`）、Gradle 依赖、国内 CDN，直连通常比走代理更稳。不要把代理变量无脑配进全局环境。
2. **只有 GitHub 资源需要代理**：`github.com`、`githubusercontent.com` 上的文件和 release 归档，直连经常失败或下成 0 字节。
3. **代理协议要分清**：
   - `curl`、`git` 建议用 `socks5h://` 地址（末尾的 `h` 表示 DNS 解析也走代理，避免域名解析失败）。
   - NuGet、npm、部分命令行工具不认 socks5，只能用 `http://` 形式的代理地址。
4. **localhost 和内网永远不走代理**。
5. **跑测试前设置 `NO_PROXY`**：测试进程通过本地 WebSocket 连接，代理开着的时候会被拦截，表现为所有用例报 `Unable to connect to flutter_tester process`，看起来像代码坏了，其实是代理问题。

   PowerShell：

   ```powershell
   $env:NO_PROXY = "127.0.0.1,localhost"
   flutter test
   ```

   macOS / Linux：

   ```bash
   NO_PROXY=127.0.0.1,localhost flutter test
   ```

---

## 3. Fork、Clone 与首次运行

### 3.1 Fork 仓库

1. 打开我的仓库：[github.com/June6699/dart_simple_live](https://github.com/June6699/dart_simple_live)。
2. 点击右上角 **Fork** 按钮，在你自己的 GitHub 账号下创建一份分叉。
3. 建议**取消勾选** "Copy the master branch only" 之外的选项保持默认即可。

### 3.2 Clone 到本地

把 `你的用户名` 替换成你的 GitHub 用户名：

```bash
git clone https://github.com/你的用户名/dart_simple_live.git
cd dart_simple_live
```

然后给本地仓库加一个指向官方仓库的远端，方便以后同步最新代码：

```bash
git remote add upstream https://github.com/June6699/dart_simple_live.git
```

之后你的仓库会有两个远端：

- `origin`：你自己的 fork，用来推送你的改动。
- `upstream`：官方仓库，只读，用来同步官方的最新提交。

### 3.3 拉取依赖

主 App 通过路径依赖直接引用 `simple_live_core`，所以在 App 工程里执行一次即可，Dart 会自动带上 core：

```bash
cd simple_live_app
flutter pub get
```

TV App 同理（需要开发 TV 时再执行）：

```bash
cd ../simple_live_tv_app
flutter pub get
```

### 3.4 把项目跑起来

先看有哪些可用设备：

```bash
flutter devices
```

常见的目标：

```bash
# Windows 桌面（需要装 Visual Studio C++ 工作负载）
flutter run -d windows

# Android 真机（打开手机开发者模式和 USB 调试）或已启动的安卓模拟器
flutter run -d android

# macOS
flutter run -d macos

# Linux 桌面
flutter run -d linux
```

第一次构建会慢一些，属于正常现象。启动成功、能看到首页，说明环境完全就绪。

### 3.5 保持与官方同步

开始新功能前，先把官方的最新代码合进来，避免后面提 PR 时冲突：

```bash
git fetch upstream
git checkout master
git merge upstream/master
```

---

## 4. 代码地图

不需要记住全部，知道"什么东西大概在哪"就够了。

### 4.1 核心库 `simple_live_core/`

```
lib/
├── simple_live_core.dart        # 统一导出文件，新增文件要在这里加 export
└── src/
    ├── interface/
    │   ├── live_site.dart       # 站点基类：取流、搜索、分类、房间详情等全部方法定义
    │   └── live_danmaku.dart    # 弹幕基类：start / stop / 心跳 / 消息回调
    ├── bilibili_site.dart       # 五个平台的站点实现
    ├── douyu_site.dart
    ├── huya_site.dart
    ├── douyin_site.dart
    ├── kuaishou_site.dart
    ├── danmaku/                 # 五个平台的弹幕实现（含 protobuf 定义）
    ├── common/                  # 共享设施：HTTP 客户端、UA、签名、错误分类、日志脱敏等
    └── model/                   # 数据模型：房间、清晰度、播放地址、消息、分类等
```

`LiveSite` 是理解整个 core 的钥匙。它定义了一个直播平台需要提供的全部能力：房间详情（`getRoomDetail`）、播放清晰度和地址（`getPlayQualites` / `getPlayUrls`）、搜索（`searchRooms` / `searchAnchors`）、分类（`getCategores` / `getCategoryRooms`）、直播状态（`getLiveStatus`）、弹幕（`getDanmaku`）等。

### 4.2 主 App `simple_live_app/`

```
lib/
├── main.dart                    # 启动入口，initServices() 里是全部全局服务的注册清单
├── app/
│   ├── sites.dart               # 平台注册表：Sites.allSites，id 到站点实例的映射
│   ├── constant.dart            # 全局常量：平台 id、事件名、页面定义
│   ├── controller/              # 设置控制器等全局控制器
│   └── utils.dart               # 弹窗、工具函数
├── modules/                     # 业务页面，按功能分目录
│   ├── live_room/               # 直播间（最大的模块，含播放器控制器）
│   ├── home/、follow_user/、category/、search/、mine/、iptv/、settings/、sync/ ...
├── services/                    # 全局服务：账号、数据库、同步、备份、通知等
├── requests/                    # App 层网络封装
├── widgets/                     # 可复用组件：房间卡片、设置项组件、状态组件等
└── routes/                      # 路由表和路径常量
```

启动流程简化为：`main()` 里依次完成错误捕获、播放器初始化、Hive 初始化、`initServices()` 逐个注册全局服务，然后 `runApp`。**新增一个全局服务，就要在 `initServices()` 里挂号。**

### 4.3 TV App `simple_live_tv_app/`

目录结构与主 App 同构（`app/`、`modules/`、`services/`、`widgets/`），但控制器是独立实现，多了遥控器焦点导航（`Focus` 节点遍布页面）和崩溃日志服务。TV 端没有后台播放的概念，因为它本身就是前台设备。

### 4.4 怎么快速定位代码

不要从头翻文件，用搜索：

- 找某个设置项存哪了：搜设置名称对应的存储键常量（集中在 `local_storage_service.dart`）。
- 找某个页面的逻辑：进 `modules/<功能名>/`，通常是 `xxx_page.dart`（界面）+ `xxx_controller.dart`（逻辑）的组合。
- 找平台相关逻辑：先看 `app/sites.dart` 的注册表，再顺着进 core 的 `xxx_site.dart`。
- 全局搜索关键词（中文文案、方法名、类名）是最常用的手段，IDE 里快捷键是 `Ctrl + Shift + F`（Windows / Linux）或 `Cmd + Shift + F`（macOS）。

---

## 5. 用 AI 开发功能的正确姿势

### 5.1 选哪个模型

- **豆包 2.1 pro**：能力足够覆盖本项目绝大多数改动，价格便宜，有免费额度，新手首选。
- **DeepSeek**：使用广泛，社区资料多，长代码任务表现稳定。

其他模型（Claude、通义、Cursor 内置模型等）不必纠结，工作流完全一样。本文不教任何具体工具的操作，自行决定用什么AI，重要的是必须 flutter 自检通过。

### 5.2 核心原则：AI 是执行者，不是许愿机

直接甩一句"给我加个 XX 平台"，大概率得到一堆看起来像模像样、实际跑不起来的代码。正确的分工是：

1. **你来定方向和验收**：做什么、改哪里、什么算做完。
2. **AI 负责出方案和写代码**：但它的每一份产出都要经过你的验证。
3. **先定位，再动手**：哪怕是让 AI 干，也要先把相关文件找出来、把上下文喂全。

### 5.3 怎么喂上下文

AI 不知道你的仓库长什么样，上下文给得越全，产出越靠谱。通常需要贴：

- 要修改的文件的**完整内容**（不要只截一半，它需要知道 import 和现有结构）。
- 相关的接口 / 基类定义（比如改站点就贴 `live_site.dart`）。
- 一个最接近的现有实现作为风格参考（比如新增平台时贴一个最简单的现有站点文件）。
- 完整的报错日志，而不是只说"报错了"。
- 如果是参考其他开源项目，把对应项目的关键源码或接口文档贴给它。

文件很大、贴不下时，让 AI 先告诉你"需要看哪几个文件"，你再逐个提供。

### 5.4 标准工作流

每一个功能都按这个节奏走，不要跳步：

1. **第一轮：让它读代码、讲方案。** 要求它列出要改哪几个文件、每个文件改什么、为什么这么改，**先不要写代码**。
2. **你确认方案。** 方案不对就当场纠正，比如"不要动默认行为""这个文件不该改"。
3. **第二轮：让它按确认的方案写代码。** 要求最小改动，不顺手重构无关代码。
4. **本地验证。** 静态分析、测试、实际运行（见第八节）。
5. **有问题把报错完整回贴，让它修。** 修到完全通过为止。
6. 最终设备实测。

### 5.5 提示词模板

下面三个模板可以直接改改用，方括号里的内容替换成你的实际情况。

**模板一：修 Bug**

```text
我在开发 Simple Live，一个 Flutter 项目（状态管理 GetX，播放器 media_kit）。

问题现象：[描述现象]
复现步骤：[1. ... 2. ...]
预期行为：[应该是什么样]

相关文件完整代码如下：
[贴文件]

完整报错日志如下：
[贴日志]

请先帮我分析根因，给出最小修复方案，不要直接改代码。我确认方案后你再写。
```

**模板二：加小功能 / 改 UI**

```text
项目背景：Simple Live，Flutter + GetX + media_kit，空安全模式。

我要在 [页面名称 / 文件路径] 增加功能：[描述想要的效果]。

相关文件完整内容如下：
[贴文件]

约束：
1. 不改变用户已习惯的现有默认行为。
2. 遵守现有代码风格，使用空安全。
3. 只做最小改动，不要重构无关代码。
4. 先列出要改哪几个文件、每个文件改什么，等我确认后再写代码。
```

**模板三：新增直播平台**

```text
我要给 Simple Live 新增一个直播平台：[平台名]。

站点基类 LiveSite 的定义如下：
[贴 live_site.dart]

现有参考站点实现（最接近的一个）如下：
[贴一个现有 xxx_site.dart 和对应弹幕文件]

目标平台的接口资料 / 参考开源项目的关键代码如下：
[贴 Python / JS 参考项目的源码或接口文档]

请先输出完整实现计划：需要新建哪些文件、每个方法如何实现、主 App 和 TV App
分别怎么注册、是否需要账号服务，确认计划后再开始写 Dart 代码。
```

### 5.6 大厂平台的正确做法

抖音、快手、斗鱼这类平台有签名算法、风控参数，接口不是裸奔的。让 AI 凭空编造签名逻辑是死路，正确做法：

1. 去 README 的"参考及引用"列表和 GitHub 上找成熟的开源项目（Python、JS、Kotlin 写的都可以）。
2. 让 AI 读懂参考项目里取流、签名、弹幕的完整逻辑。
3. 让它**逐方法翻译**成 Dart，复用本项目 `common/` 里已有的 HTTP 客户端、UA、签名执行器（项目内置了 quickjs 执行 JS 签名）。
4. 每翻译一个方法就验证一个，不要等全部写完。

### 5.7 AI 常见翻车清单

| 翻车类型 | 表现 | 防法 |
|----------|------|------|
| 编造 API | 写出项目里根本不存在的类、方法，或 pub.dev 上没有的包 | 跑 `flutter analyze` 验证；新依赖让它给出 pub.dev 链接，加依赖必须在 PR 说明理由 |
| 改串文件 | 把主 App 的改动写进了 TV App 的同名文件，或反过来 | 提示词里写死工程的完整路径；收到代码先核对文件路径 |
| 无视 lint | 留下 warning 就交差 | 本项目 `flutter analyze` 对 warning 也判失败，必须修到 `No issues found!` |
| GetX Obx 零读 | `Obx` 回调里没有实际读取任何响应式变量，运行时抛 `improper use of a GetX`，release 下表现为页面空白 | 检查每个 Obx 内部是否至少同步读取了一个 `.value` / `.obs` 变量 |
| 顺手大重构 | 改一个小功能，捎带重写了半个文件 | 要求最小改动；无关重构让它撤回，重构要单独成 commit |
| 乱改版本号 / 锁文件 | 改 pubspec 版本号、提交 `pubspec.lock` | 版本号由维护者发版时统一处理，`pubspec.lock` 不进版本库 |
| 协议解析想当然 | 字段名、数据结构靠猜，实跑就崩 | 解析类逻辑必须写测试或实跑验证，不能只看代码"感觉对" |

---

## 6. 实战：给听直播页加一个音量滑块

走一遍完整流程，目标是让你看到真实的协作节奏。

**需求**：听直播模式（纯音频页面）目前只有播放 / 暂停按钮，加一个音量滑块，拖动就能调音量。

### 6.1 第一步：定位文件

- 页面文件：`simple_live_app/lib/modules/live_room/listen_live_page.dart`
- 页面里通过 `Get.find<LiveRoomController>()` 拿到控制器，控制器暴露的 `player` 是 media_kit 的 `Player` 实例。
- media_kit 提供 `player.setVolume(value)`（范围 0–100）和 `player.stream.volume`（音量变化流）、`player.state.volume`（当前值）。

### 6.2 第二步：让 AI 出方案

把 `listen_live_page.dart` 完整贴给豆包，用模板二的思路提问：

```text
我要在听直播页的播放按钮下方加一个音量滑块。
播放器实例是 controller.player（media_kit 的 Player），
音量范围 0-100，可用 player.stream.volume 监听、player.setVolume 设置。
请先说明你打算把组件插在 Column 的什么位置、用什么 Widget 实现，先不要写代码。
```

AI 会给出方案：在播放控制按钮和底部提示文字之间，用 `StreamBuilder<double>` 监听音量流，内部放一行音量图标 + `Slider`。确认这个位置和交互合理，再让它写代码。

### 6.3 第三步：实现

得到的代码大致是这样（这就是可以直接用的实现风格）：

```dart
// 插在播放控制 Row 与底部提示文字之间
StreamBuilder<double>(
  stream: controller.player.stream.volume,
  initialData: controller.player.state.volume,
  builder: (context, snapshot) {
    final volume = snapshot.data ?? 100;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded, color: Colors.white70),
          Expanded(
            child: Slider(
              value: volume,
              min: 0,
              max: 100,
              onChanged: (value) => controller.player.setVolume(value),
            ),
          ),
          const Icon(Icons.volume_up_rounded, color: Colors.white70),
        ],
      ),
    );
  },
)
```

### 6.4 第四步：验证

1. 在工程目录执行静态分析：

   ```bash
   flutter analyze
   ```

   修到输出 `No issues found!`。

2. 实际运行：

   ```bash
   flutter run -d windows
   ```

   进一个直播间，切换到听直播模式，拖动滑块，确认音量实时变化、播放 / 暂停和定时关闭都没有受影响。

3. 有安卓设备的话再跑一遍 `flutter run -d android`，确认触屏拖动正常。

到这里，一个完整的功能就开发完了，后面就是提交 PR 的流程。

---

## 7. 新增直播平台 checklist

新增平台是最受欢迎的 PR 类型之一，但改动点分散，按下面的清单逐项打勾，避免漏改。

### 7.1 动手前先调研

- 这个平台有没有公开的网页端或公开接口？
- 接口是否需要签名 / 加密？如果需要，有没有成熟的开源实现可以参考？
- 弹幕走什么协议（WebSocket / 长连接 / 自定义 TCP）？
- 完全封闭、没有任何公开资料的平台，不要硬上，先到 Discussions 讨论可行性。

### 7.2 核心库层（`simple_live_core/`）

1. 新建 `lib/src/xxx_site.dart`：写一个 `XxxSite` 类，现有站点都用 `implements LiveSite`；如果平台能力简单、不想实现全部方法，也可以 `extends LiveSite` 只覆写需要的方法。
2. 逐个实现：`id`、`name`、`getDanmaku()`、房间详情、清晰度与播放地址、搜索、分类、直播状态。用不到的能力可以保留基类的空实现。
3. 新建 `lib/src/danmaku/xxx_danmaku.dart`：继承 `LiveDanmaku`，实现连接、心跳（`heartbeat` / `heartbeatTime`）、消息解析，通过 `onMessage` 回调把消息抛出去。
4. 在 `lib/simple_live_core.dart` 里加上新文件的 `export`。
5. 平台 UA 等指纹信息放进 `src/common/` 里对应的共享文件，不要散落在站点代码中。

### 7.3 主 App 层（`simple_live_app/`）

1. `lib/app/constant.dart` 加平台 id 常量。
2. `lib/app/sites.dart` 的 `Sites.allSites` 里注册新平台（id、名称、logo、`liveSite` 实例）。
3. logo 图片放进 `assets/images/`（该目录已整体注册为资产，不用改 pubspec）。
4. 平台需要 Cookie 才能工作的话：
   - 新建 `lib/services/xxx_account_service.dart`，参考现有账号服务的写法（读取存储、`setSite()` 把 Cookie 注入 core 站点实例）。
   - 在 `lib/main.dart` 的 `initServices()` 里注册这个服务。
   - 在 `local_storage_service.dart` 里加存储键名常量。

### 7.4 TV App 层（`simple_live_tv_app/`）

1. 同步修改 `constant.dart` 和 `app/sites.dart`，完成同样的注册。
2. 需要 Cookie 的平台，账号服务同步到 TV 工程。
3. 用遥控器走一遍焦点导航，确认新平台入口和页面能正常聚焦、打开。

### 7.5 同步体系（仅当平台带 Cookie 时）

Cookie 会在多个通道之间流转，新增时四处必须对齐：

1. 本地存储键名。
2. 局域网同步的服务端路由。
3. 全量配置包（Profile）里的 accounts 结构。
4. 远程房间同步的 action 定义。

### 7.6 测试与验证

1. 在 `simple_live_core/test/` 下加测试：优先覆盖不依赖网络的逻辑（URL 解析、数据结构转换、字段解析）。
2. 跑通 `flutter test` 和 `flutter analyze`。
3. 真机 / 模拟器完整走一遍：搜索主播、搜索房间、分类浏览、进房、取流播放、弹幕接收、Cookie 登录（如适用）。

---

## 8. 构建与验证

日常开发和提 PR 不需要关心维护者的正式发布流程，标准 Flutter 命令就够用。维护者有自己的私有构建脚本用于正式发版，**贡献者不要去复刻发布流程，也不要把构建产物提交进仓库。**

### 8.1 三道必过的验证关

每次提交前，在你改动的工程目录下依次执行：

```bash
# 1. 静态分析：注意 warning 也算失败，必须修到 No issues found!
flutter analyze

# 2. 单元测试：core 工程的测试最完整，改动 core 必跑
flutter test

# 3. 实际运行：涉及 UI 的改动必须在对应平台实际点一遍
flutter run -d <设备>
```

### 8.2 构建安装包自测

需要验证 release 包表现时，用标准命令：

```bash
# Android：按 ABI 拆包，产出 armeabi-v7a / arm64-v8a / x86_64 三个包
flutter build apk --release --split-per-abi

# Windows 桌面
flutter build windows --release

# Linux 桌面
flutter build linux --release
```

构建产物在工程的 `build/` 目录下，这个目录已经被 gitignore，不会进提交，自己装到设备上验证即可。

### 8.3 构建时的网络注意

- 依赖拉取走国内镜像直连，不要挂代理。
- Windows 首次构建需要从 GitHub 下载原生归档（ANGLE、libmpv），这一步如果失败或下成 0 字节，给 `curl` 配 `socks5h` 代理重试，不要硬重试。
- 构建失败过一次后再重试，建议先执行 `flutter clean` 再重新 `flutter pub get`，半截缓存会导致各种假性报错（找不到 lib、链接错误等）。
- 跑测试记得带 `NO_PROXY=127.0.0.1,localhost`，见 [2.7 节](#27-国内网络与代理)。

### 8.4 不要改版本号

`pubspec.yaml` 顶部的 `version` 和 build 号由维护者发版时统一处理，提功能 PR 时**不要修改版本号**，也不要提交 `pubspec.lock`（仓库明确忽略它）。

### 8.5 注意账号与数据字段的多通道同步

如果你改动了**会被同步的数据字段**——比如新增某个平台的 Cookie、给弹幕屏蔽加更多设置、给关注 / 历史 / 自定义分区等加字段，就不能只改本地读写，必须让所有同步方式都能识别这个新字段。

目前数据一共会经过四条通道，也就是四个地方都要改、同步更新：

| 通道 | 实现位置 | 承载内容 |
|------|----------|----------|
| 配置包导入导出 | `ProfileBackupService`（带 schema 版本管理） | 设置、账号、弹幕屏蔽、关注、标签、历史、IPTV、自定义分区 |
| 局域网同步 | `SyncService` 的 `/sync/*` 路由 | 同一 Wi-Fi 下设备直连，按数据类型分路由 |
| WebDAV 备份 | `modules/sync/remote_sync/webdav/` | 备份到自己的 WebDAV 存储 |
| 远程房间同步 | `SignalrService` + 独立同步服务器 | 代码在 [June6699/simple-live-sync-site](https://github.com/June6699/simple-live-sync-site)，贡献者没有部署权限，协议变更由我处理 |

为什么必须逐条对齐：同一个最新版本，用户在 A 设备设置好、同步到 B 设备，如果 B 设备上的 App 不认识这个字段，这项设置就等于悄悄丢了，过程中不会有任何报错，用户也无从排查。

> [!NOTE]
> 关于"未知字段兼容"：App 做了容错——无法识别的字段不会让同步崩溃：设置类的未知键会原样保留，无法识别的账号等内容会被安全跳过，schema 版本也支持多个历史版本。
>
> 但注意，容错只保证不崩，不保证能同步：旧版 App 依然读不懂新字段、不会产生对应行为。所以不能跳过同步方式对应。

提交 PR 时的具体要求：

1. 在 PR 描述里逐条说明四条通道分别怎么处理；即使某条通道不涉及，也要明确确认它不受影响。
2. 如果改动需要远程同步支持新的 action，不要假设服务器行为，在 PR 里写明需要的协议字段和触发情况，由我同步修改并部署服务器。
3. 改动 Hive 实体或序列化结构时，注意旧数据的 decode 兼容：解析失败应静默丢弃或走迁移，不能抛错卡住启动。

---

## 9. 提交 PR

### 9.1 分支规范

从最新的 `master` 切出功能分支，分支名带上类型：

```bash
git checkout master
git fetch upstream
git merge upstream/master
git checkout -b feat/xxx-platform
```

常用前缀：`feat/`（新功能）、`fix/`（修复）、`refactor/`（重构）、`docs/`（文档）。

### 9.2 提交信息规范

使用 Conventional Commits 格式，正文用中文写清楚动机：

```text
feat(core): 新增 xxx 直播平台站点
fix(ui): 修复直播间 Obx 零读导致的空白页
refactor(iptv): 抽离 m3u 解析公共逻辑
docs: 补充贡献指南
```

**一次改动按逻辑单元拆成多个 commit**：功能实现、顺手重构、评审后的补充调整，分别提交，互不相关的东西不要塞进同一个 commit。

调试脚本、临时探针、下载的临时文件、本地构建产物，一律不进提交。提交前用 `git status` 逐项核对。

### 9.3 推送并发起 PR

```bash
git push origin feat/xxx-platform
```

然后在 GitHub 上打开你的仓库，点击 **Compare & pull request**，目标分支选官方仓库的 `master`。

PR 描述建议写清楚这几块：

1. **背景**：解决什么问题，对应哪个 Issue / Discussion（有链接就贴上）。
2. **实现**：改了哪几个文件、核心思路是什么。
3. **验证**：跑了哪些命令、在什么设备上验证过、结果如何。
4. **截图或录屏**：UI 改动强烈建议附上，评审效率会高很多。
5. **其他说明**：有没有新增依赖、有没有需要维护者额外注意的地方。

### 9.4 关于 CI 和评审

- 本仓库的 GitHub Actions 配置为**手动触发或发版 tag 触发，PR 不会自动跑构建**，所以不要等 CI 帮你查问题，所有验证在本地完成。
- 评审人提出修改意见时，在原分支继续提交即可，PR 会自动更新。
- 可以合并的 PR，维护者有时会在合并后自己做微调，并在 PR 里说明改了什么；你的署名会完整保留。
- 保持耐心：评审是人工进行的，不要反复催；被要求修改不代表被否定，具体到行为的修改意见恰恰说明 PR 在被认真对待。

---

## 10. 红线：这些 PR 不会被合并

README 里有一份完整的"绝对禁止更新的功能"清单，这里给出核心分类，提交前对照检查：

> 不碰账号，不碰钱，不碰写操作，不碰官方活动。

- **账号体系**：官方登录注册、实名、绑定手机、未成年人模式，以及账号维度的关注 / 拉黑 / 消息已读等。
- **钱**：充值、钱包、余额、礼物、订单、退款、优惠券、打赏、上舰等一切付费相关。
- **写操作 / 互动**：发送弹幕评论、点赞、私信、投票、PK 助力、连麦申请、群聊等一切"发出去"的动作。
- **治理功能**：举报、申诉、房管、禁言、踢人。
- **官方活动与成长体系**：抽奖、福袋、红包、签到、任务中心、经验勋章、主播后台、开播工具。
- **下载与完整复刻**：离线缓存、录播下载、源流下载、批量导出；完整的首页推荐流、热榜、消息中心；能替代官方 App 的完整回放 / 追更体系。
- **破解**：付费房间破解、伪造平台账号cookie（假账号）。
- **暂时不准备合并的功能**：录屏功能

本项目的定位是**只读的聚合观看工具**。以上功能的 PR 不会被评审通过，不用花时间做。完整清单以 README 为准。

此外，项目仅用于学习交流，严禁商业用途；不要在 PR 里引入破解等内容。

---

## 11. 沟通渠道

- **[GitHub Discussions](https://github.com/June6699/dart_simple_live/discussions)**：功能建议、平台适配、使用经验、一般提问都发这里，先搜旧帖，有相同需求就给主楼点 Upvote，不要重复开帖。
- **[GitHub Issues](https://github.com/June6699/dart_simple_live/issues)**：只用于报 Bug，按模板填写复现步骤和日志；非 Bug 类 Issue 请到 [Discussions](https://github.com/June6699/dart_simple_live/discussions)。
- **QQ 群 / 微信**：入口见 [README](https://github.com/June6699/dart_simple_live#)，适合直接反馈问题和日常交流。

最后，感谢愿意花时间把功能做出来的每一位贡献者。好用的项目，正是从一个个 PR 开始的。
