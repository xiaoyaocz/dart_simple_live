# [Windows] 1.11.7 退出直播间返回列表时高概率闪退（flutter_windows.dll / 0xC0000005 / 固定偏移 0x2c4527）

> 仅文档报告，不含代码改动。
> 版本：simple_live_app 1.11.7（MSIX，包标识 com.xycz.simplelive_1.11.7.0_x64）
> 平台：Windows 11（Build 26200）
> 报告日期：2026-11-05

## 一、问题概要

Windows 桌面版进入任意直播间、待视频画面真正开始渲染后，点击左上角返回退出播放页，**有较高概率进程直接消失（无任何报错弹窗）**。应用可正常启动、正常选台、正常播放，崩溃只发生在“退出播放页”这一步。

## 二、复现步骤

1. 启动 Simple Live 1.11.7（MSIX 安装版）。
2. 在首页点击任意直播间卡片，等待 5~10 秒，确认画面与弹幕已正常渲染。
3. 点击播放页左上角返回箭头，回到首页。
4. 重复 1~3 次，约每 2~3 次出现一次闪退（进程消失）。

补充对照测试：

| 操作 | 次数 | 结果 |
|---|---|---|
| 进入直播间后立刻（≤2.5s，画面尚未渲染）返回 | 5 | 5/5 正常 |
| 进入直播间并播放 6 秒后返回 | 6 | 第 3 次闪退 |
| 关闭「设置 → 直播间设置 → 播放器 → 硬件解码」后再测 | 6 | 第 3 次闪退（签名不变） |

结论：崩溃只在**视频纹理已激活后**返回时触发；关闭硬件解码无法规避。

## 三、崩溃现场数据（Windows 事件日志）

来源：`事件查看器 → Windows 日志 → 应用程序 → Application Error`

| 项目 | 值 |
|---|---|
| 应用 | simple_live_app.exe，版本 1.11.7.11107 |
| 异常代码 | **0xC0000005（访问冲突）** |
| 故障模块 | **flutter_windows.dll**，版本 0.0.0.0，时间戳 0x6a852865 |
| 故障偏移 | **0x00000000002c4527（多次崩溃完全一致）** |
| 异常偏移 | 0x00000000002c4527 |
| 运行时长 | 约 70 秒（含播放 5~10 秒） |

另有一个变体：异常代码 0xC0000409（fail-fast），故障模块同为 flutter_windows.dll，偏移 0xfb44e9。

历史统计（同一台测试机近 90 天，同一应用）：

| 版本 | 故障模块 | 异常码 | 次数 |
|---|---|---|---|
| 1.11.4 | dcomp.dll | 0xE0464645 | 65 |
| 1.11.7 | dcomp.dll | 0xE0464645 | 19 |
| 1.11.7 | flutter_windows.dll | 0xC0000005（偏移 0x2c4527） | 12 |
| 1.11.7 | flutter_windows.dll | 0xC0000409（偏移 0xfb44e9） | 3 |
| 1.11.4 | permission_handler 插件 | 0xC0000005 / 0xC000041D | 2 |

即：该问题自 2026-08-12 起持续存在，升级到 1.11.7 后从 dcomp 崩溃变为 flutter_windows.dll 固定偏移崩溃，属于长期存在的问题，不是单次环境异常。

## 四、测试环境

- 系统：Windows 11 Build 26200（25H2 通道）
- 机型：双显卡笔记本，NVIDIA RTX 3050 Laptop + Intel UHD（核显驱动 31.0.101.3222，2022/7）
- 显示：2560×1600，150% 缩放，显示器开启 HDR
- 系统设置：硬件加速 GPU 计划（HAGS）开启
- 常驻：NVIDIA App / Overlay（尝试结束进程后会被 NVIDIA 容器自动重启，未能确认完全排除）
- 无 TDR / 驱动复位记录（系统日志干净）

## 五、分析（供参考）

1. 崩溃签名**确定且固定**（同一模块、同一偏移、多次一致），更符合引擎侧一条确定的代码路径，而非随机内存/驱动问题。
2. 触发条件与“视频纹理已激活”强相关：画面未渲染时快速返回 5/5 正常。
3. 推测链路：`LiveRoomController` 销毁 → `media_kit` 的 `Player` / `VideoController` 释放 → 注销外部视频纹理，而引擎光栅线程此时仍可能持有一帧待合成的纹理，形成 use-after-free，落在 `flutter_windows.dll` 的固定偏移。
4. 1.11.7 使用 Flutter 3.38 引擎（README 标注），不排除是引擎升级后 external texture / 窗口销毁路径的行为变化引发的回归。
5. 关闭硬件解码后签名不变，说明与 mpv 硬解（hwdec）无直接关系，更可能是**纹理注销时序**问题。

## 六、建议的修复方向（供作者参考）

1. 在离开播放页时**先停止播放再注销纹理**，并保证异步顺序：
   - `await player.stop()` → `await videoController.dispose()` → 再 `Navigator.pop()`；
   - 或在 `onClose` 中延迟一帧（`WidgetsBinding.instance.endOfFrame`）后再释放 `VideoController`。
2. 检查 media_kit / media_kit_video 的版本与 Flutter 3.38 的兼容性，必要时升级到修复过纹理生命周期的版本。
3. 若短期内无法定位，可在 Windows 端“返回”时改为**隐藏播放页并延迟销毁**，或提供“独立窗口播放”选项绕开该路径。
4. 建议默认开启 Windows 端日志（当前 `log` 目录为空，崩溃后无任何可分析的日志），或提供带调试符号的构建用于定位 0x2c4527。

## 七、需要确认的问题

1. Windows 端 1.11.7 是否已知此问题？是否有 1.11.8 / 修复分支？
2. 能否提供 1.11.7 对应引擎的符号表或带日志的 debug 构建，以便定位 `flutter_windows.dll+0x2c4527`？
3. 是否接受“退出前先 stop + dispose 后再 pop”的补丁 PR？

---

### 附：事件日志原文（一条完整记录）

```
Faulting application name: simple_live_app.exe, version: 1.11.7.11107, time stamp: 0x6a97f164
Faulting module name: flutter_windows.dll, version: 0.0.0.0, time stamp: 0x6a852865
Exception code: 0xc0000005
Fault offset: 0x00000000002c4527
```

## 补充：2026-11-05 第二轮实测（重启 + 新驱动后）

### 1. 配置与结果对照

| 配置 | 4K 切换结果 | 崩溃签名 |
|---|---|---|
| 旧驱动 32.0.15.9649 + 165Hz + 硬件解码关 | 崩溃 | `dcomp.dll` `0xE0464645` offset `0x7fed4` |
| 新驱动 32.0.16.2101 + 165Hz + 硬件解码开 | 先卡约 90 秒，随后闪退 | `flutter_windows.dll` `0xC0000409` offset `0xfb44e9` |
| 新驱动 + 强制 NVIDIA GPU（`UserGpuPreferences`） | 同上 | `flutter_windows.dll` `0xC0000409` offset `0xfb44e9` |
| 新驱动 + 刷新率 60Hz | 同上 | `flutter_windows.dll` `0xC0000409` offset `0xfb44e9` |

结论：三种互不相同的环境配置（GPU 选择 / 刷新率 / 驱动版本）得到完全相同的 fail-fast 偏移，说明 4K 切换是确定性代码路径缺陷，不是显卡驱动或合成层可调项。

### 2. 返回闪退复核（新驱动后）

- 7 次「播放 6 秒 → 返回」：第 4 次崩溃，`flutter_windows.dll` `0xC0000005` offset `0x2c4527`，与更新驱动前完全一致 → 与驱动无关。
- 对照：720p ↔ 1080p 切换 6 次全部正常；2.5 秒内快速返回 5/5 正常（视频纹理尚未激活）。

### 3. 4K 冻结阶段的进程状态

- 冻结期间进程 `Responding=True`、CPU 约单核 11%、无 TDR、无 AppHang 记录 → 卡在渲染/上屏，随后由引擎 fail-fast 终止；
- 先切 2K 再切 4K 与直接切 4K 结果相同，均触发 `0xfb44e9`。

### 4. 建议排查点（补充）

- `VideoController` 生命周期：切清晰度时 `player.open()` 会以新的 4K 尺寸重建纹理，若旧 `Texture` 未释放或尺寸未更新，可能触发引擎侧断言；
- `onClose()` 中 `await player.dispose()` 与路由 pop 的时序：建议先销毁视频纹理/控制器，再延迟一帧释放 `Player`。

附：本轮事件日志见 `docs/reports/attachments/simple-live-crash-events-round2.txt`。
