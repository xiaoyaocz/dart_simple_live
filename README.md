

<p align="center">
    <img width="128" src="/assets/logo.png" alt="Simple Live logo">
</p>
<h2 align="center">Slive</h2>

<p align="center">
我就默默看你表演
</p>

![浅色模式](/assets/screenshot_light.jpg)

![深色模式](/assets/screenshot_dark.jpg)

## 支持直播平台：

- 虎牙直播

- 斗鱼直播

- 哔哩哔哩直播

- 抖音直播

## APP支持平台

- [x] Android 
- [x] iOS `自测`
- [x] Windows 
- [x] MacOS `自测`
- [x] Linux
- [ ] Android TV `请自行打包` [说明](https://github.com/SlotSun/dart_simple_live/issues/89)

只保证Android, Linux和Windows可用性

请到[Releases](https://github.com/slotsun/dart_simple_live/releases)下载最新版本，iOS请到上游或者action下载体验

Arch Linux: ```yay -S slive```


如果想体验最新功能，可前往[Actions](https://github.com/slotsun/dart_simple_live/actions)下载自动打包的开发版本

Windows建议下载UWP版[聚合直播](https://www.microsoft.com/store/apps/9N1TWG2G84VD)，体验会更好


## 项目结构

- `simple_live_core` 项目核心库，实现获取各个网站的信息及弹幕。
- `simple_live_console` 基于simple_live_core的控制台程序。
- `simple_live_app` 基于核心库实现的Flutter APP客户端。
- `simple_live_tv_app` 基于核心库实现的Flutter Android TV客户端。

## 环境

flutter 3.38.4

## 参考及引用

[AllLive](https://github.com/xiaoyaocz/AllLive) `本项目的C#版，有兴趣可以看看`

[dart_tars_protocol](https://github.com/xiaoyaocz/dart_tars_protocol.git)

[lovelyyoshino/Bilibili-Live-API](https://github.com/lovelyyoshino/Bilibili-Live-API/blob/master/API.WebSocket.md)

[IsoaSFlus/danmaku](https://github.com/IsoaSFlus/danmaku)

[BacooTang/huya-danmu](https://github.com/BacooTang/huya-danmu)

[TarsCloud/Tars](https://github.com/TarsCloud/Tars)

[5ime/Tiktok_Signature](https://github.com/5ime/Tiktok_Signature)

[biliup](https://github.com/biliup/biliup)

[stream-rec](https://github.com/stream-rec/stream-rec)

## 声明

本项目的所有功能都是基于互联网上公开的资料开发，无任何破解、逆向工程等行为。

本项目仅用于学习交流编程技术，严禁将本项目用于商业目的。如有任何商业行为，均与本项目无关。

如果本项目存在侵犯您的合法权益的情况，请及时与开发者联系，开发者将会及时删除有关内容。
