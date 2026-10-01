# MSG · MacSpaceGuard

[中文](#中文说明) · [English](#english)

## 中文说明

MSG 是一个轻量、完全本地运行的 macOS 菜单栏工具，用来监测内存与磁盘状态，并辅助整理白名单中的旧缓存和下载安装包。

**当前版本：0.3.7 预览版。** 1.0 尚未发布，仓库目前提供源码。目标平台为 Apple Silicon（M 系列）Mac，构建最低要求 macOS 13；最低系统和另一台 Mac 的兼容性仍待实测。应用界面目前为中文，暂不支持 Intel。

### 功能

- 菜单栏显示系统内存余量、估算内存使用、交换空间及磁盘剩余量。
- 自动检查间隔可选 1、3、6、12 小时，默认 6 小时；自动检查只统计。
- 选择缓存目录与日期，扫描后逐文件选择；支持全选、风险提示及运行中应用的额外确认。
- 检查所选文件夹第一层的 `.dmg`、`.pkg`，只读查看包内应用标识与版本，并与本机安装情况对照；不会运行安装程序。
- 用户确认后将所选文件移到废纸篓，不卸载应用，不自动清空废纸篓。
- 支持本地通知、登录时启动；没有主动上传文件或扫描结果的功能。

### 使用边界

清理磁盘缓存不等于释放运行内存。文件修改时间较早也不保证可以安全移除；建议先退出相关应用，查看路径和风险理由再确认。

只扫描白名单中的指定缓存子目录，不扫描整个资源库；不处理 `Application Support`、`Containers`、`Logs`、聊天数据库、浏览器密码或文稿。完整范围见[清理范围](docs/CLEANUP_SCOPE.md)。

移到废纸篓后仍占用磁盘空间，需要用户自行检查并清空才会释放。清空前可尝试从废纸篓恢复；恢复不保证能撤销应用已经发生的异常。

### 安装与反馈

当前没有经发布验收的公开安装包。之后的安装包会放在 [Releases](https://github.com/Dimoo-rich/MacSpaceGuard/releases)，下载 DMG，打开后拖入“应用程序”。不要把 GitHub 自动生成的 **Source code** 压缩包当安装包。

本项目按零预算发布路线准备：使用临时本地签名，暂不办理付费 Developer ID 签名或 Apple 公证。未来提供下载时会明确标注这一点，并说明首次打开可能出现的系统提示。具体流程见[安装说明](docs/INSTALL.md)。

反馈请使用 [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues)。可提供版本、系统版本和问题步骤，截图请隐去用户名和私人文件名。[隐私说明](docs/PRIVACY.md) · [验收记录与剩余风险](docs/SAFETY_AUDIT.md) · [版本记录](CHANGELOG.md)

## English

MSG is a lightweight, local-only macOS menu bar app for monitoring memory and disk space, and managing old caches and downloaded installers.

**Current version: 0.3.7 preview.** Version 1.0 is not released. The repository currently provides source code. The target is Apple Silicon Macs, with a macOS 13 deployment minimum; compatibility with the oldest supported OS and a second Mac still needs verification. The app UI is currently in Chinese. Intel Macs are out of scope.

### Features

- Shows memory availability, estimated memory usage, swap usage, and free disk space.
- Checks every 1, 3, 6, or 12 hours; the default is 6 hours. Scheduled checks only report findings.
- Reviews allowlisted caches with a date cutoff, explicit file selection, and risk explanations.
- Inspects `.dmg` and `.pkg` files in the selected folder's top level without executing installers. Compares application metadata with installed applications; matching does not prove installation provenance.
- Moves selected files to macOS Trash only after confirmation, with extra confirmation for caches associated with running apps.
- Supports local notifications and launch at login. Does not actively upload files or scan results.

### Limits and installation

Removing disk caches does not directly free RAM. Older files may still be in use. The allowlist excludes application data, chat databases, browser credentials, documents, and whole Library directories. Review findings and quit the relevant app before moving its caches.

Moving files to Trash does not immediately free disk space. MSG never empties Trash; users decide when to empty it after reviewing its contents.

There is currently no public installer that has passed release acceptance. Future installers will be attached to [Releases](https://github.com/Dimoo-rich/MacSpaceGuard/releases). GitHub's **Source code** archives are not installers. The zero-budget distribution plan uses ad-hoc signing without Developer ID or Apple notarization; this limitation will be clearly disclosed. See the [English installation guide](docs/INSTALL.en.md).

Report problems through [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues). Include the app version, macOS version, and reproduction steps. Remove private names and paths from screenshots before sharing.

## Development / 本地开发

Requires an Apple Silicon Mac and Swift 6 tools. Full XCTest requires Xcode. With Command Line Tools only, the self-test can run using temporary fixtures and a simulated Trash. The existing CI workflow runs tests and packages a preview DMG on a GitHub Mac runner; a successful CI run does not replace real installation and Trash acceptance tests.

```sh
swift run --disable-sandbox MacSpaceGuardSelfTest
swift test --disable-sandbox
./scripts/package_app.sh
./scripts/create_dmg.sh
```

Build output: `dist/.build/MacSpaceGuard.app` and `dist/MacSpaceGuard.dmg`.

If the local compiler and default SDK do not match, set a compatible `SDKROOT`. The packaging script includes a fallback for a known Command Line Tools SDK layout. See [distribution notes](docs/DISTRIBUTION.md) for optional future signing and notarization.

## License

[MIT License](LICENSE).
