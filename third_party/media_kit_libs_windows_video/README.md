# [package:media_kit_libs_windows_video](https://github.com/media-kit/media-kit)

[![](https://img.shields.io/discord/1079685977523617792?color=33cd57&label=Discord&logo=discord&logoColor=discord)](https://discord.gg/h7qf2R9n57) [![Github Actions](https://github.com/media-kit/media-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/media-kit/media-kit/actions/workflows/ci.yml)

Windows package providing video (& audio) native libraries for [`package:media_kit`](https://github.com/media-kit/media-kit).

This project-local variant keeps the stable `media_kit` Windows renderer and
refreshes only the bundled libmpv runtime. The upstream package still points
at a 2023 build; this copy uses the generic x86_64 2026-08-28 build so that
Windows hardware-decoder selections such as `d3d11va` are honored.

Visit [media-kit/libmpv-win32-video-cmake@`master`](https://github.com/media-kit/libmpv-win32-video-cmake) & [media-kit/libmpv-win32-video-build@`master`](https://github.com/media-kit/libmpv-win32-video-build) for descriptive details.

## License

Copyright © 2021 & onwards, Hitesh Kumar Saini <<saini123hitesh@gmail.com>>

This project & the work under this repository is governed by MIT license that can be found in the [LICENSE](./LICENSE) file.
