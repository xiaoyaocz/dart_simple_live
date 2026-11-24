# Simple Live IPTV 源收集与使用说明

本文档收录 Simple Live 预置与推荐使用的公开 IPTV 直播源，全部经本机直连实测（不走代理），附来源链接、更新频率、覆盖范围与软件内使用方法。数据实测时间 2026-11-21。


## 一、源总览

| 名称 | 作者 | 更新频率 | 频道规模 | 覆盖 | 直连实测 |
|------|------|----------|----------|------|----------|
| suxuang全量源 | suxuang | 每日 | 约 2600 条线路 | 央视/卫视/地方，多节点容灾 | 可达 |
| vbskycn全量源 | vbskycn | 每 6 小时 | 约 340 频道 | 央视/卫视/地方，省份分组完整 | 可达 |
| zhi35聚合源 | zhi35 | 每日 3 更 | 328 频道 | 央视/卫视/地方/港澳台/直播中国，IPv4+IPv6 | 可达 |
| fanmingming咪咕源 | fanmingming | 每日多更 | 189 频道 | 咪咕/央视频 CDN，央视体育齐全 | 可达 |
| fanmingmingIPv6源 | fanmingming | 每日多更 | 82 频道 | 央视/卫视，需 IPv6 网络 | 可达 |
| hujingguang实时源 | hujingguang | 小时级 | 405 频道 | 央视+省市台，近实时抓取 | 可达 |
| hacks.tools日更源 | hacks.tools | 每日多次 | 341 频道 | 卫视/地方/电影/儿童丰富，央视较少 | 可达 |
| xisohi全量源 | xisohi | 约每周 | 1200+ 条 | 央视/卫视/地方/教育/台港澳 | 可达 |
| iptv-org国际源 | iptv-org | 每日自动校验 | 11567 频道 | 全球国际频道 | 可达 |
| DataShare海外源 | DataShare-duo | 不定期 | 以发布为准 | 海外 CDN，适配境外网络 | 可达 |
| peterh镜像源 | peterhchina | 每日 | 同 vbskycn | vbskycn 镜像备份 | 可达 |


## 二、各源详情与地址

### 2.1 suxuang全量源

项目地址：[suxuang/myIPTV](https://github.com/suxuang/myIPTV)

- 播放列表：`https://raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u`
- 加速镜像：`https://ghfast.top/https://raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u`
- 备用镜像：`https://gh-proxy.com/raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u`
- M3U 格式，实测 2685 行，线路全部为 http/https 直播流，无 udp 组播
- 央视频道完整，CCTV5 实测存在多条线路


### 2.2 vbskycn全量源

项目地址：[vbskycn/iptv](https://github.com/vbskycn/iptv)

- 播放列表：`https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u`
- 加速镜像：`https://ghfast.top/https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u`
- 备用镜像：`https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u`
- 备用地址：`https://peterhchina.github.io/iptv/IPTV-V4.m3u`
- TXT 格式变体：`https://raw.githubusercontent.com/vbskycn/iptv/master/tv/iptv4.txt`（`#genre#` 分组格式，Simple Live 解析器兼容）
- 400+ 频道，省份分组完整，GitHub Actions 每 6 小时自动更新


### 2.3 zhi35聚合源

项目地址：[zhi35/iptv](https://github.com/zhi35/iptv)，在线播放站：[live.zhi35.com](https://live.zhi35.com/)

- 播放列表（CDN 加速，优先用）：`https://live.zhi35.com/iptv.m3u`
- 原始地址：`https://raw.githubusercontent.com/zhi35/iptv/master/iptv.m3u`
- 加速镜像：`https://ghfast.top/https://raw.githubusercontent.com/zhi35/iptv/master/iptv.m3u`
- GitHub Actions 每日 3 更（北京时间 09:00 / 17:00 / 01:00），实测当日 01:25 已更新
- 频道分组：央视频道 24、卫视频道 37、地方频道 171、CHC 电影 1、港澳台 16、直播中国 79
- 线路含 57 条 IPv6 地址（中国移动组播转 HTTP），IPv4 网络下这些线路会失败，播放器自动换线兜底
- 自带 EPG：`https://live.zhi35.com/epg.xml.gz`（实测可达，含当日回看 catchup 参数）


### 2.4 fanmingming（最知名源，GPL-3.0）

项目地址：[fanmingming/live](https://github.com/fanmingming/live)（28900+ stars，Simple Live 预置按列表拆成两个源）

- 咪咕列表（预置「fanmingming咪咕源」）：`https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/itv.m3u`
  189 频道，全部走咪咕/央视频 CDN（`gslbserv.itv.cmvideo.cn`），全国可用，央视与体育频道齐全
- IPv6 列表（预置「fanmingmingIPv6源」）：`https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u`
  82 频道，全部为移动 IPv6 线路，==需终端支持 IPv6==（大陆家宽与手机流量普遍已具备）
- 区域锁定列表（未预置，供参考）：`https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/index.m3u`
  94 频道（卫视高清 31/卫视备用 30/央视高清 18/央视备用 15），线路为广东运营商区域源，异地大概率不可播
- 自带 EPG：`https://live.fanmingming.cn/e.xml`；台标域名 `live.fanmingming.cn`（本机实测该 CDN 域名直连超时，列表文件走 GitHub raw 不受影响）
- 附带回看 catchup 参数（`catchup="append"`），支持时移的播放器可回看


### 2.5 hujingguang实时源

项目地址：[hujingguang/ChinaIPTV](https://github.com/hujingguang/ChinaIPTV)

- 播放列表：`https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV1_ALL.m3u8`
- 加速镜像：`https://ghfast.top/https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV1_ALL.m3u8`
- 实测 405 频道，分组含央视台、上海台及各省分台；README 标注每 15 分钟从直播网站重新抓取，提交记录为小时级
- 专项列表：`cnTV2_GuoNei.m3u8`（87 频道）、`Global.m3u8`（60 频道）、`HongKong.m3u8`、`TaiWan.m3u8` 等，港澳台需境外网络
- 台标引用 fanmingming 域名，列表文件本身不受影响


### 2.6 hacks.tools日更源

项目地址：[iptv.hacks.tools](https://iptv.hacks.tools/)

- 播放列表：`https://live.hacks.tools/tv/iptv4.m3u`
- TXT 变体：`https://live.hacks.tools/tv/iptv4.txt`（`#genre#` 分组格式）
- 按分类取用（无需全量时）：`https://live.hacks.tools/tv/ipv4/categories/央视频道.m3u`，分类含央视/卫视/地方/电影/体育/儿童/戏曲/春晚/直播中国等
- 实测当日 07:57 更新（HTTP Last-Modified 与列表内嵌更新时间一致），Cloudflare CDN 直连快
- 分组规模：地方频道 185、电影频道 66、纪录频道 23、卫视频道 22、央视频道 15（==当前构建无 CCTV1 与 CCTV5，央视频道请依赖其他源==）


### 2.7 xisohi全量源

项目地址：[xisohi/CHINA-IPTV](https://github.com/xisohi/CHINA-IPTV)

- 播放列表：`https://raw.githubusercontent.com/xisohi/CHINA-IPTV/main/TV/live.txt`
- 加速镜像：`https://ghfast.top/https://raw.githubusercontent.com/xisohi/CHINA-IPTV/main/TV/live.txt`
- TXT `#genre#` 格式，实测 1218 条线路，分组：央视/卫视/地方/教育/台港澳/其它
- 仓库另有 31 省单播目录（`Unicast/<省份>/`）与运营商组播目录（`Multicast/`），配套站点 [chinaiptv.pages.dev](https://chinaiptv.pages.dev)
- 更新频率约每周，胜在同频道多冗余线路


### 2.8 iptv-org国际源

项目地址：[iptv-org/iptv](https://github.com/iptv-org/iptv)（Unlicense 公有领域）

- 播放列表：`https://iptv-org.github.io/iptv/index.m3u`
- 加速镜像：`https://live.hacks.tools/iptv/index.m3u`
- 实测 11567 个频道，按国家/语言/分类拆分子列表（见项目 PLAYLISTS.md），中国子列表 `https://iptv-org.github.io/iptv/countries/cn.m3u` 以海外华语频道为主
- 知乎推荐文：[iptv-org：一个不存视频却收藏全球电视频道的开源项目](https://zhuanlan.zhihu.com/p/2049431538249601225)


### 2.9 DataShare海外源

项目地址：[DataShare-duo/IPTV-Source](https://github.com/DataShare-duo/IPTV-Source)

- 播放列表：`https://raw.githubusercontent.com/DataShare-duo/IPTV-Source/refs/heads/main/movie_live.txt`
- 加速镜像：`https://ghfast.top/https://raw.githubusercontent.com/DataShare-duo/IPTV-Source/refs/heads/main/movie_live.txt`
- 海外节点直连、CDN 加速，适合境外网络环境使用


### 2.10 peterh镜像源

项目地址：[peterhchina/iptv](https://peterhchina.github.io/iptv/)

- 播放列表：`https://peterhchina.github.io/iptv/IPTV-V4.m3u`
- vbskycn 源的镜像备份，每日更新


### 2.11 专项列表与广播

- zhi35 直播中国（景区/城市实景慢直播，79 个）：`https://live.zhi35.com/live-china.m3u`
- zhi35 电台广播（159 个 FM 频道）：`https://live.zhi35.com/radio.m3u`
- hacks.tools IPv6 源：`https://live.hacks.tools/tv/iptv6.m3u`（当前为占位空表，需 IPv6 网络且等作者恢复数据）
- YanG-1989 聚合（体育/游戏/影视轮播为主，无央视）：`https://raw.githubusercontent.com/YanG-1989/m3u/main/Gather.m3u`
- Guovin/iptv-api：[26200 stars 的自建聚合工具](https://github.com/Guovin/iptv-api)，适合自部署生成私人源；其官方托管输出已数月未更新，不建议直接引用


## 三、软件内使用方法

### 3.1 预置源

以上源均已内置为预置源，启动后自动聚合全部启用源的频道，跨源同名频道合并为多线路。管理入口：

- 手机/桌面端：我的 → 账号管理 → IPTV 直播源区域，可启停、删除、恢复默认
- TV 端：设置 → 播放 → IPTV直播源管理，支持启停、删除、添加自定义源

不喜欢的源直接停用或删除即可，停用的源不参与聚合，也不会被刷新请求访问。


### 3.2 导入自己的 M3U 源

网上搜到的任意 M3U/TXT 地址（如 `https://a.autom3u.com/playlist/country/cn.m3u`）按以下步骤导入：

1. 打开账号管理页（TV 端为设置 → IPTV直播源管理）
2. 点「添加自定义源」，填写名称与地址
3. 确定后软件自动校验：8 秒内拉取并解析，成功提示解析到的频道数；地址不可达或解析为空不会写入
4. 添加即参与聚合，回到 IPTV 频道页即可播放

支持 M3U（`#EXTINF`）与 TXT（`#genre#`）两种格式，相对地址自动按订阅源 URL 补全。


### 3.3 按来源浏览与探活

- 频道页顶部可切换「按分组 / 按来源」两个维度；按来源时选择某个源，只显示含该源线路的频道
- 每个频道下方按线路源显示探活胶囊：绿=连通快（2 秒内）、黄=连通慢、红=探测失败、灰点=未检测（超出单轮 500 条探测上限或检测中）
- 摘要行显示「共 N 条线路 · 可用 M 条」；播放器内「线路选择」列表同样标注每条线路的连通状态与延迟毫秒数


### 3.4 更新与刷新

- 公开源均为日更级，软件内聚合缓存按自然日失效：当天首次进入频道页自动重拉，当天内不再重复请求
- 刷新时可选部分源：点刷新按钮弹出源选择框（记忆上次选择），未选中的源沿用上次拉取结果，不再发起请求；选择会持久化，每日自动刷新同样遵循该范围
- 手动刷新当天成功一次后按钮置灰（提示「今日已更新」），次日自动恢复；不做后台定时更新，重启软件即完成当天更新
- 起播自动寻优：记忆源线路探测为红时，起播自动改选探测连通最快的线路；播放失败或长时间缓冲自动换线的兜底链路保持不变


> [!WARNING]
> 频道可用性随时段波动明显，探活结果只是参考信息（10 分钟缓存）；某源整体失效时删除或停用该源即可，播放失败会自动换线下一条线路。


## 四、实测说明

- 全部地址于 2026-11-21 在大陆网络环境下直连（不经代理）实测
- `raw.githubusercontent.com` 直连可达但偶发截断；GitHub 加速镜像 `ghfast.top` 实测可用，`gh-proxy.com` 在实测当天晚些时候出现超时——两镜像均已按「原始 → ghfast.top → gh-proxy」顺序配置兜底
- hacks.tools 与 zhi35 的 EPG 头字段（x-tvg-url）部分第三方 EPG 地址在当前网络不可达，zhi35 自带 EPG 可用
- 频道数、分组数为实测当天的快照，以各项目实时发布为准
