> ### Release
>
> 本仓库提供阶段性 `Release` 安装包与压缩包，见 GitHub Releases 页面。
>
> 私有开发主仓会更频繁更新；公开仓库只在阶段性整理后同步。

<p align="center">
    <img width="128" src="/assets/logo.png" alt="Simple Live logo">
</p>
<h2 align="center">Simple Live</h2>

<p align="center">
简简单单的看直播
</p>

![浅色模式](/assets/screenshot_light.jpg)

![深色模式](/assets/screenshot_dark.jpg)

## 仓库说明

- 当前公开仓库：`June6699/dart_simple_live`
- 当前私有开发仓库：`June6699/dart_simple_live_own`
- 当前公开仓库保留 fork 关系，用于明确声明上游来源与修改基础
- fork 来源：
  - 原作者仓库：[xiaoyaocz/dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live)

说明：

- 日常开发以私有仓库为主
- 公开仓库会做阶段性同步，并保留 fork 标签
- 公开同步时会剔除部分仅供私有开发使用的脚本与文档

## Release 资产

当前提供这些正式资产：

- Android `apk`
- Windows `zip`
- Linux `zip`
- Linux `deb`
- source code zip

## 支持直播平台

- 虎牙直播
- 斗鱼直播
- 哔哩哔哩直播
- 抖音直播

## APP 支持平台

- [x] Android
- [x] iOS
- [x] Windows `BETA`
- [x] MacOS `BETA`
- [x] Linux `BETA`
- [x] Android TV `BETA`

## 项目结构

- `simple_live_core`：项目核心库，实现各个平台的信息获取与弹幕处理
- `simple_live_console`：基于 `simple_live_core` 的控制台程序
- `simple_live_app`：基于核心库实现的 Flutter APP 客户端
- `simple_live_tv_app`：基于核心库实现的 Flutter Android TV 客户端

## 环境

Flutter：`3.38`

## 当前已完成的改动

### Fix

- 修复聊天区用户名和内容的首尾空格问题，并修复用户名过长时单独换行的问题。
- 修复虎牙头条 / SC 显示异常、重复刷新、价格异常和旧数据残留问题。
- 修复直播间内“正在连接弹幕服务器”“线路选择”“线路 N”等中文文案乱码。
- 修复直播间标题居中逻辑被右侧操作栏影响的问题。
- 修复 B 站贡献榜重复更新、刷新异常的问题，并改进贡献榜按需刷新逻辑。
- 修复 Windows 小窗、全屏、窗口恢复、鼠标自动隐藏等一系列桌面播放器问题。
- 修复安卓后台恢复与直播间恢复逻辑，提升应用被系统回收后的可恢复性。

### Optimize

- 弹幕显示从“上下间距”调整为“显示几行”，并根据显示区域和字体大小动态计算。
- 弹幕延迟支持按平台单独微调。
- 贡献榜增加前十、粉丝牌、高贡献等筛选。
- 分类页在缺少原始图标时提供统一占位图标。
- 同类推荐、观看历史、用户快捷操作等直播间交互继续补强。

### Update

- 弹幕屏蔽升级为分平台管理，并支持关键词 / 用户分别一键清空。
- 弹幕屏蔽预设支持导入、导出、编辑和保存覆盖。
- 直播间内点击用户可进行屏蔽、临时禁言、备注、复制、批量恢复等操作。
- 新增 `B站 / 抖音 / 斗鱼` 贡献榜或亲密榜展示能力。
- 发布链路已拆成 Android / Windows / Linux 三条独立工作流，macOS 改为手动入口。

## 下一步计划

当前优先考虑这些方向：

- 继续补完部分平台接口细节，例如分区字段、标签图标、推荐逻辑反查。
- 继续研究虎牙贡献榜的稳定方案，如果网页端不稳定，再评估 APP 侧接口或保底方案。
- 继续补强安卓直播间底部按钮与虚拟导航栏重叠的问题。
- 继续优化聊天区自动滚动、推荐直播、贡献榜筛选和临时交互能力。
- 继续完善公开发布与私有开发双仓库流程，让公开仓库只保留适合公开的内容。

## 参考及引用

[AllLive](https://github.com/xiaoyaocz/AllLive) `本项目的 C# 版，有兴趣可以看看`

[xiaoyaocz/dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live) `当前公开仓库的上游 fork 来源`

[dart_tars_protocol](https://github.com/xiaoyaocz/dart_tars_protocol.git)

[wbt5/real-url](https://github.com/wbt5/real-url)

[lovelyyoshino/Bilibili-Live-API](https://github.com/lovelyyoshino/Bilibili-Live-API/blob/master/API.WebSocket.md)

[IsoaSFlus/danmaku](https://github.com/IsoaSFlus/danmaku)

[BacooTang/huya-danmu](https://github.com/BacooTang/huya-danmu)

[TarsCloud/Tars](https://github.com/TarsCloud/Tars)

[YunzhiYike/douyin-live](https://github.com/YunzhiYike/douyin-live)

[5ime/Tiktok_Signature](https://github.com/5ime/Tiktok_Signature)

## 声明

本项目的功能基于互联网上公开资料整理与开发，无任何破解、逆向工程等行为。

本项目仅用于学习交流编程技术，严禁用于商业目的。如有任何商业行为，均与本项目无关。

如果本项目存在侵犯您合法权益的情况，请及时联系开发者，开发者会及时处理相关内容。

## Star History

<a href="https://www.star-history.com/#xiaoyaocz/dart_simple_live&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date" />
 </picture>
</a>
