# Windows 应用层直连

范围：仅 Windows 应用内网络；保留其他平台网络策略、WebView 原 profile 路径和全部用户数据，不操作系统/用户代理设置。

1. 备份现有改动文件到独立临时目录，列出 Dart/Dio/WebSocket/WebDAV、WebView 两条环境创建路径、mpv 和安装器启动链。
2. 先写回归：全局 Dart DIRECT 覆盖原代理；默认 Dio/core/app HTTP、WebSocket 与远程同步不得到达测试代理；旧 WebView profile 仍保留而参数始终禁用代理。
3. Windows 启动最早安装 HttpOverrides；远程同步取消 Windows 注册表代理读取；原生 runner 仅清除自身进程代理变量（同时覆盖 Win32/CRT）；mpv 初始化（首个流打开之前）清空 http-proxy；WebView 显式和默认环境在创建前添加 no-proxy-server。
4. 运行新回归、完整应用测试、原生环境清理测试；编译真实 Windows 主入口及独立网络探针。
5. 不改变系统代理，用继承的故障代理环境及实际 TCP 连接观察验证；功能项分别记录实际通过/未验证，不以接口夹具代替安装版 UI 或实发验收。
6. 使用既有安装器打包、校验嵌入文件；记录修改清单、备份和逐文件回滚方式。不覆盖运行中的用户程序。
