<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

## 概述

一个使用 `CustomPainter` 进行直接绘制的简易高性能 `flutter` 弹幕组件

## 示例

``` yaml
dependencies:
  canvas_danmaku: ^0.2.7
```

Example:

```dart

import 'package:canvas_danmaku/canvas_danmaku.dart';

class _DanmakuPageState extends State<DanmakuPage> {
    late DanmakuController _controller;
    @override
    Widget build(BuildContext context) {
        return Stack(
        children: [
            // 你的自定义组件，例如一个播放器
            Container(),
            // 弹幕组件
            DanmakuScreen(
            createdController: (e) {
                _controller = e;
            },
            option: DanmakuOption(),
            ),
        ],
        );
    }
}

```

## 说明

本项目接口设计参考 `ns_danmaku` ，支持 `ns_danmaku` 的大部分功能。本项目与其的区别在于弹幕绘制原理。

## 特性

#### 高性能

`canvas_danmaku` 通过底层的 `CustomPainter` 直接绘制弹幕。这可以减少 Flutter 框架中组件的数量，降低了组件树的复杂度，从而提高性能。

`canvas_danmaku` 特别优化了过度重绘问题。滚动弹幕与静止弹幕分层处理，静止弹幕仅在需要时重绘。此外，当没有弹幕时，`canvas_danmaku` 会优雅地暂停所有绘制，并在重新出现弹幕时优雅地重新开始绘制。

`canvas_danmaku` 渲染准备与渲染操作异步。渲染准备在弹幕添加时进行并缓存，每帧直接使用缓存而无需渲染准备。渲染缓存只在弹幕添加时生成，或在弹幕属性变动时(例如更改字体)重新生成。

#### 简单

`canvas_danmaku` 不依赖于上下文，不需要传递 `BuildContext`。

`canvas_danmaku` 也不需要传递 弹幕容器高度/弹幕轨道数 等控制弹幕布局的信息。

`canvas_danmaku` 是响应式的，弹幕容器高度会根据父组件自适应，弹幕轨道数根据当前容器高度与字体大小动态计算。

`canvas_danmaku` 弹幕容器属性(字体大小/字体透明度等)可在容器运行时热更新，渲染缓存将会在发生热更新时优雅地销毁并重新生成。

## 局限

如前文所述，本项目绘制的弹幕本质是一段动画，而非一组小组件。故本项目绘制的弹幕不具有交互性，如果您需要点击弹幕来实现的交互操作，本项目并不能满足需求。

## 致谢

[xiaoyaocz/ns_danmaku](https://github.com/xiaoyaocz/flutter_ns_danmaku) 本项目的灵感来自 ns_danmaku ，一个非常优秀的项目。
