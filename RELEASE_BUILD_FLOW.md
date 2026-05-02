# SimpleLive Release 预编译与发布流程

这份文档记录当前仓库已经调整好的正式发布流程。现在 `Android / Windows / Linux` 已经拆成 3 条独立的自动工作流，`macOS` 只保留手动入口，不再参与自动发布，也不会再把整次发布标成失败。

## 1. 适用范围

- 主应用：`simple_live_app`
- 当前正式发布产物：
  - Android 单个 `apk`
  - Windows `zip`
  - Linux `zip`
  - Linux `deb`
  - source code zip
- 当前不再自动发布：
  - macOS
  - iOS
  - Windows `msix`

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

## 3. 当前工作流划分

当前主应用发布相关工作流已经拆成 4 个文件：

- [publish_app_release.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release.yml)
  - Android 自动发布
  - 触发方式：推送 `v*` tag
- [publish_app_release_windows.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release_windows.yml)
  - Windows 自动发布
  - 触发方式：推送 `v*` tag
- [publish_app_release_linux.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release_linux.yml)
  - Linux 自动发布
  - 触发方式：推送 `v*` tag
- [publish_app_release_macos_manual.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release_macos_manual.yml)
  - macOS 手动构建入口
  - 触发方式：`workflow_dispatch`
  - 默认不参与正式发布
  - 就算构建失败，也不应该把这条工作流标成阻塞性的失败

## 4. 发布前原则

1. 尽量不要用脏工作区直接打最终发布包。
2. 最稳的方式是：
   - 本地先做功能验证
   - 正式 Release 优先采用 GitHub Actions 对应 tag 的构建产物
3. 如果某一条工作流失败，不要影响另外两条的发布判断：
   - Android 只看 Android
   - Windows 只看 Windows
   - Linux 只看 Linux
4. 当前不要把 macOS 成败作为正式发版阻塞条件。

## 5. 版本号修改

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

## 6. 本地预验证

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

### Linux

通常不在本机直接打 Linux 包，正式发布优先依赖 GitHub Actions。

## 7. 标准 Release 流程

### 7.1 提交代码并推送

```powershell
cd C:\softwares\dart_simple_live
git status
git add .
git commit -m "Release v1.12.0"
git push origin master
```

### 7.2 打 tag 触发 3 条自动工作流

```powershell
cd C:\softwares\dart_simple_live
git tag -f v1.12.0
git push origin v1.12.0 --force
```

这一步会分别触发：

- Android 工作流
- Windows 工作流
- Linux 工作流

不会自动触发 macOS。

### 7.3 查看工作流状态

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh run list --repo June6699/dart_simple_live --limit 20
```

建议分别确认这 3 条工作流成功：

- `app-build-android-release`
- `app-build-windows-release`
- `app-build-linux-release`

如果只想看某一条：

```powershell
gh run list --repo June6699/dart_simple_live --workflow publish_app_release.yml --limit 10
gh run list --repo June6699/dart_simple_live --workflow publish_app_release_windows.yml --limit 10
gh run list --repo June6699/dart_simple_live --workflow publish_app_release_linux.yml --limit 10
```

## 8. 正式发布资产的本地归档规则

每个版本都整理到：

- `release\v版本号`

例如：

- `C:\softwares\dart_simple_live\release\v1.12.0`

推荐结构：

```text
release\
  v1.12.0\
    android\
    linux\
    windows\
    source\
    _tmp\
```

其中：

- `android`：最终正式 APK
- `linux`：最终 `deb` 和 `zip`
- `windows`：最终 `zip`
- `source`：`git archive` 生成的源码压缩包
- `_tmp`：临时下载、解压目录

## 9. 当前正式 Release 资产命名

当前目标是保留这几项：

- `simple_live_app-<app_version>-android.apk`
- `simple_live_app-<app_version>-windows.zip`
- `simple_live_app-<app_version>-linux.zip`
- `simple_live_app-<app_version>-linux.deb`
- `dart_simple_live-v<semver>-source.zip`

例如 `1.12.0+11200`：

- `simple_live_app-1.12.0+11200-android.apk`
- `simple_live_app-1.12.0+11200-windows.zip`
- `simple_live_app-1.12.0+11200-linux.zip`
- `simple_live_app-1.12.0+11200-linux.deb`
- `dart_simple_live-v1.12.0-source.zip`

## 10. CI 成功后的常规收尾

如果 3 条自动工作流都成功，则只需要：

1. 检查 Release 资产是否完整
2. 下载 Windows 和 Linux 正式产物到 `release\v版本号`
3. 本地生成或核对 source zip
4. 用 Windows `zip` 刷新 `C:\softwares\SimpleLive`

示例：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release view v1.12.0 --repo June6699/dart_simple_live --json assets,url
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-windows.zip" -D C:\softwares\dart_simple_live\release\v1.12.0\windows
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-linux.zip" -D C:\softwares\dart_simple_live\release\v1.12.0\linux
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-linux.deb" -D C:\softwares\dart_simple_live\release\v1.12.0\linux
```

## 11. 常用兜底流程

如果某条工作流成功构建了产物，但 release 上传阶段异常，可以用下面方式补齐。

### 11.1 下载某条工作流 artifact

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh run download <run_id> --repo June6699/dart_simple_live -n android -D C:\softwares\dart_simple_live\release\v1.12.0\_tmp\android_artifact
gh run download <run_id> --repo June6699/dart_simple_live -n windows -D C:\softwares\dart_simple_live\release\v1.12.0\_tmp\windows_artifact
gh run download <run_id> --repo June6699/dart_simple_live -n linux -D C:\softwares\dart_simple_live\release\v1.12.0\_tmp\linux_artifact
```

### 11.2 生成 source code zip

```powershell
cd C:\softwares\dart_simple_live
git archive --format=zip --output=C:\softwares\dart_simple_live\release\v1.12.0\source\dart_simple_live-v1.12.0-source.zip v1.12.0
```

### 11.3 手动补传 Release

```powershell
$env:HTTP_PROXY='http://127.0.0.1:10808'
$env:HTTPS_PROXY='http://127.0.0.1:10808'
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH

gh release upload v1.12.0 --repo June6699/dart_simple_live --clobber `
  C:\softwares\dart_simple_live\release\v1.12.0\android\simple_live_app-1.12.0+11200-android.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\windows\simple_live_app-1.12.0+11200-windows.zip `
  C:\softwares\dart_simple_live\release\v1.12.0\linux\simple_live_app-1.12.0+11200-linux.zip `
  C:\softwares\dart_simple_live\release\v1.12.0\linux\simple_live_app-1.12.0+11200-linux.deb `
  C:\softwares\dart_simple_live\release\v1.12.0\source\dart_simple_live-v1.12.0-source.zip
```

## 12. macOS 预留入口说明

当前 macOS 不参加自动发布，但入口保留在：

- [publish_app_release_macos_manual.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release_macos_manual.yml)

使用方式：

1. 去 GitHub Actions 手动触发 `app-build-macos-manual`
2. `ref` 可以填 `master`、某个 tag，或者具体 commit
3. 默认只做手动构建和 artifact 输出
4. 如果以后确认稳定，再手动打开 `upload_release`

当前约束：

- macOS 构建失败不应该影响 Android / Windows / Linux
- macOS 构建失败也不应该再成为正式发布是否成功的判断标准

## 13. Release 上传失败时的代理处理

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

## 14. Release 页面清理规则

发版完成后应保证：

- 最终只保留一个正式 `vX.Y.Z` Release
- 不应再混入 `msix`
- 不应再混入 macOS 自动发布产物

检查：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release list --repo June6699/dart_simple_live --limit 20
gh release view v1.12.0 --repo June6699/dart_simple_live --json assets,url
```

## 15. 每次发版后的最终核对清单

1. `simple_live_app/pubspec.yaml` 版本号正确
2. Git tag 正确，格式为 `vX.Y.Z`
3. 3 条自动工作流分别成功：
   - Android
   - Windows
   - Linux
4. 正式 Release 至少包含：
   - Android `apk`
   - Windows `zip`
   - Linux `zip`
   - Linux `deb`
   - source code zip
5. 本地 `release\vX.Y.Z` 已归档完成
6. `C:\softwares\SimpleLive` 已刷新为该版本 Windows 预编译

## 16. 建议的最短执行顺序

下次赶时间时，按这套最短顺序走：

1. 改 `simple_live_app/pubspec.yaml` 版本号
2. 本地验证：
   - `.\build_android_apk.bat --no-pause`
   - `.\deploy_windows.bat --no-pause`
3. 提交并 push `master`
4. 打 `vX.Y.Z` tag 并 push
5. 分别看 Android、Windows、Linux 3 条工作流
6. 检查正式 Release 资产是否齐全
7. 本地归档 `release\vX.Y.Z`
8. 刷新 `C:\softwares\SimpleLive`

照这个流程执行，当前仓库就能稳定完成一轮 Android / Windows / Linux 发版，而不会再被 macOS 阻塞。
