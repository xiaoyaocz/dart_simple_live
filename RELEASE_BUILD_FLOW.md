# SimpleLive Release 预编译与发布流程

这份文档记录当前仓库已经跑通的一套 `Android + Windows + Linux` Release 流程，目标是下次发版时可以直接照着做，不再重复踩坑。

## 1. 适用范围

- 主应用：`simple_live_app`
- 主要发布产物：
  - Android APK
  - Windows `zip` / `msix`
  - Linux `zip` / `deb`
  - source code zip
- 当前 `macOS / iOS` 不是本次必须项，失败不会阻塞安卓、Windows、Linux 的交付

## 2. 当前机器依赖路径

本机默认使用这些目录：

- Flutter：`C:\softwares\flutter`
- Git：`C:\softwares\Git`
- GitHub CLI：`C:\softwares\GitHubCli`
- Java：`C:\softwares\Java`
- JDK 17：`C:\softwares\jdk-17`
- Android SDK：`C:\softwares\Android_Sdk`
- Android Studio Projects：`C:\softwares\AndroidStudioProjects`

本地常用输出目录：

- Release 汇总目录：`C:\softwares\dart_simple_live\release`
- 本机自用 Windows 预编译目录：`C:\softwares\SimpleLive`
- Android 本机自用目录：`C:\softwares\SimpleLiveAndroid`

## 3. 发布前原则

1. 尽量不要用脏工作区直接打最终发布包。
2. 最稳的方式是：
   - 本地只做功能验证
   - 正式发布资产优先使用 `tag` 对应的 CI 产物
3. 如果工作区里还有未完成改动，最终 Release 资产优先从 GitHub Actions / Git tag 导出，不要直接拿本地 `build` 目录里的文件当最终产物。

## 4. 版本号修改

主应用版本号当前在：

- [simple_live_app/pubspec.yaml](/C:/softwares/dart_simple_live/simple_live_app/pubspec.yaml)

例如：

```yaml
version: 1.12.0+11200
```

发布时要保证：

1. `pubspec.yaml` 里的版本号已经改好
2. Git tag 使用 `v` 前缀

例如：

```powershell
git tag -f v1.12.0
git push origin v1.12.0 --force
```

## 5. 本地预验证

### Android

仓库已有脚本：

- [build_android_apk.bat](/C:/softwares/dart_simple_live/build_android_apk.bat)

推荐命令：

```powershell
cd C:\softwares\dart_simple_live
.\build_android_apk.bat --no-pause C:\softwares\SimpleLiveAndroid
```

说明：

- 这个脚本会检查 `Flutter / Android SDK / JDK / keystore`
- 成功后会把 APK 复制到 `C:\softwares\SimpleLiveAndroid\SimpleLive-release.apk`

如果需要和 Release 保持一致的多 ABI 包，也可以直接执行：

```powershell
cd C:\softwares\dart_simple_live\simple_live_app
flutter pub get
flutter build apk --release --split-per-abi
```

输出目录：

- `simple_live_app\build\app\outputs\flutter-apk\`

### Windows

仓库已有脚本：

- [deploy_windows.bat](/C:/softwares/dart_simple_live/deploy_windows.bat)

推荐命令：

```powershell
cd C:\softwares\dart_simple_live
.\deploy_windows.bat --no-pause C:\softwares\SimpleLive
```

说明：

- 会自动关闭正在运行的 `simple_live_app.exe`
- 会执行 `flutter build windows --release`
- 会把结果镜像部署到 `C:\softwares\SimpleLive`

如果只想手动构建：

```powershell
cd C:\softwares\dart_simple_live\simple_live_app
flutter pub get
flutter build windows --release
```

输出目录：

- `simple_live_app\build\windows\x64\runner\Release`

## 6. 标准 Release 流程

### 6.1 提交代码并推送

```powershell
cd C:\softwares\dart_simple_live
git status
git add .
git commit -m "Release v1.12.0"
git push origin master
```

### 6.2 打 tag 触发 GitHub Actions

当前主流程工作流：

- [.github/workflows/publish_app_release.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release.yml)

触发方式是推送 `v*` tag：

```powershell
cd C:\softwares\dart_simple_live
git tag -f v1.12.0
git push origin v1.12.0 --force
```

### 6.3 查看工作流状态

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh run list --repo June6699/dart_simple_live --limit 10
gh run view <run_id> --repo June6699/dart_simple_live --json status,conclusion,jobs,url
```

目标是确认：

- `build-windows` 成功
- `build-linux` 成功
- `build-mac-ios-android` 至少 `Build APK` 成功

## 7. 正式发布资产的本地归档规则

每个版本都整理到：

- `release\v版本号`

例如：

- `C:\softwares\dart_simple_live\release\v1.12.0`

推荐结构：

```text
release\
  v1.12.0\
    android\
    windows\
    source\
    _tmp\
```

其中：

- `android`：最终 APK
- `windows`：最终 `zip` / `msix`
- `source`：`git archive` 生成的源码压缩包
- `_tmp`：临时下载、解压目录

## 8. CI 全绿时的常规收尾

如果 GitHub Actions 自己已经把所有资产都挂到正式 Release，则只需要：

1. 下载 Release 资产到 `release\v版本号`
2. 下载 source code 或本地生成 source zip
3. 用 Windows `zip` 刷新 `C:\softwares\SimpleLive`

下载示例：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release view v1.12.0 --repo June6699/dart_simple_live --json assets,url
gh release download v1.12.0 --repo June6699/dart_simple_live -D C:\softwares\dart_simple_live\release\v1.12.0\windows
```

## 9. 常用兜底流程

这部分很重要。实际发版时，最常见的是：

- Windows / Linux 成功并上传
- Android 在 `artifact` 里有，但因为后续 `macOS` 失败，没有自动挂到正式 Release

这时按下面做。

### 9.1 下载 Android artifact

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh run download <run_id> --repo June6699/dart_simple_live -n android -D C:\softwares\dart_simple_live\release\v1.12.0\_tmp\android_artifact
```

然后把 APK 复制到：

- `C:\softwares\dart_simple_live\release\v1.12.0\android`

### 9.2 生成 source code zip

```powershell
cd C:\softwares\dart_simple_live
git archive --format=zip --output=C:\softwares\dart_simple_live\release\v1.12.0\source\dart_simple_live-v1.12.0-source.zip v1.12.0
```

### 9.3 下载 Windows 发布包

优先从正式 Release 下载：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-windows.zip" -D C:\softwares\dart_simple_live\release\v1.12.0\windows
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-windows.msix" -D C:\softwares\dart_simple_live\release\v1.12.0\windows
```

如果下载慢或失败，可以手动浏览器下载后再复制进去。

### 9.4 刷新本机 Windows 预编译目录

用正式 Release 的 Windows `zip` 刷新：

```powershell
$releaseRoot = 'C:\softwares\dart_simple_live\release\v1.12.0'
$zip = Join-Path $releaseRoot 'windows\simple_live_app-1.12.0+11200-windows.zip'
$tmpExtract = Join-Path $releaseRoot '_tmp\windows_extract'
$targetDir = 'C:\softwares\SimpleLive'

if (Test-Path $tmpExtract) { Remove-Item -LiteralPath $tmpExtract -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpExtract | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $tmpExtract -Force

Get-ChildItem -LiteralPath $targetDir -Force | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $tmpExtract '*') -Destination $targetDir -Recurse -Force
```

注意：

- 目标目录必须确认是 `C:\softwares\SimpleLive`
- 不要把删除动作指向别的路径

## 10. Release 上传失败时的代理处理

如果：

- `github.com` 能访问
- 但是上传到 `uploads.github.com` 超时

通常不是仓库权限问题，而是上传链路没走代理。

本机可用代理：

- `127.0.0.1:10808`

先测试：

```powershell
Test-NetConnection 127.0.0.1 -Port 10808
curl.exe -I -m 20 --proxy http://127.0.0.1:10808 https://uploads.github.com
```

上传前建议：

```powershell
$env:HTTP_PROXY='http://127.0.0.1:10808'
$env:HTTPS_PROXY='http://127.0.0.1:10808'
```

然后再执行：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release upload v1.12.0 --repo June6699/dart_simple_live --clobber `
  C:\softwares\dart_simple_live\release\v1.12.0\android\app-arm64-v8a-release.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\android\app-armeabi-v7a-release.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\android\app-x86_64-release.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\source\dart_simple_live-v1.12.0-source.zip
```

## 11. Release 页面清理规则

本次已经验证过，可能出现：

- 一个正式 `v1.12.0`
- 额外的同 tag `Draft Release`

发版完成后应保证：

- 最终只保留一个正式 Release

检查：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release list --repo June6699/dart_simple_live --limit 20
gh api repos/June6699/dart_simple_live/releases
```

如果有多余草稿 Release，用 `release id` 删除：

```powershell
gh api -X DELETE repos/June6699/dart_simple_live/releases/<release_id>
```

## 12. 本次已经确认过的工作流问题

### 已修复

1. `softprops/action-gh-release` 原来用了 `secrets.TOKEN`
2. 这个 secret 为空时会导致发布失败
3. 现在已经改为 `github.token`

另外：

1. Android 签名以前强依赖 `KEYSTORE_BASE64`
2. 现在工作流和 Gradle 都已经支持没有 keystore 时走兜底逻辑

### 仍然存在但不影响本次目标

`macOS` 可能失败，当前已知点是 `connectivity_plus` 与 macOS/Xcode 组合的兼容问题，典型报错类似：

```text
Value of type 'NWPath' has no member 'isUltraConstrained'
```

这会影响：

- `build-mac-ios-android` 整体结论变成 `failure`

但不代表：

- Android APK 没构建出来
- Windows / Linux 不能发

所以如果用户本次只关心：

- Android
- Windows
- Linux

则按本文第 9 节手动补齐 Release 即可。

## 13. 每次发版后的最终核对清单

1. `simple_live_app/pubspec.yaml` 版本号正确
2. Git tag 正确，格式为 `vX.Y.Z`
3. 正式 Release 页面只保留一个目标版本
4. Release 内至少包含：
   - Android 3 个 APK
   - Windows `zip`
   - Windows `msix`
   - Linux `zip`
   - Linux `deb`
   - source code zip
5. 本地 `release\vX.Y.Z` 已归档完成
6. `C:\softwares\SimpleLive` 已刷新为该版本 Windows 预编译

## 14. 建议的最短执行顺序

下次赶时间时，按这套最短顺序走：

1. 改 `simple_live_app/pubspec.yaml` 版本号
2. 本地验证：
   - `.\build_android_apk.bat --no-pause`
   - `.\deploy_windows.bat --no-pause`
3. 提交并 push `master`
4. 打 `vX.Y.Z` tag 并 push
5. 等 GitHub Actions
6. 如果 macOS 挂了但 Android artifact 已经生成：
   - 下载 Android artifact
   - 下载 Windows 正式资产
   - 本地生成 source zip
   - 用代理把 Android/source 补传到正式 Release
7. 删掉多余 Draft Release
8. 刷新 `C:\softwares\SimpleLive`

照这个流程执行，当前仓库就能稳定完成一轮 Android/Windows/Linux 发版。
