# MSG · MacSpaceGuard

[中文](#中文说明) · [English](#english)

> **下载 / Download：** [MSG 1.0.0-beta.3 · M 系列 Mac 安装包（DMG）](https://github.com/Dimoo-rich/MacSpaceGuard/releases/download/v1.0.0-beta.3/MSG-1.0.0-beta.3-AppleSilicon.dmg)
>
> **公开测试版 / Public beta，非稳定版。** 仅 Apple Silicon，中文界面；未经 Apple 公证，另一台 Mac 与最低系统尚未实测。首次安装请先阅读[中文安装说明](docs/INSTALL.md) / [English installation guide](docs/INSTALL.en.md)。
>
> [发布说明与附件 / Release & assets](https://github.com/Dimoo-rich/MacSpaceGuard/releases/tag/v1.0.0-beta.3) · [SHA256 校验文件](https://github.com/Dimoo-rich/MacSpaceGuard/releases/download/v1.0.0-beta.3/SHA256.txt) · [反馈问题 / Report an issue](https://github.com/Dimoo-rich/MacSpaceGuard/issues)

## 中文说明

MSG 是一个轻量的 macOS 菜单栏工具，用来查看内存与磁盘状态、管理白名单旧缓存，以及整理下载的安装包。扫描与文件处理在本机进行；beta.3 增加可选联网更新查询。

**公开下载：1.0.0-beta.3（公开测试版，不是稳定版）。** 目标为 Apple Silicon（M 系列）Mac，界面为中文，不支持 Intel。编译最低版本为 macOS 13，但最低系统和另一台 Mac 尚未实测；请勿将此理解为已验证的 macOS 13+ 兼容性承诺。

### 功能与本次范围

- 查看系统内存余量、估算内存使用、交换空间及磁盘剩余量。
- 自动检查间隔可选 1、3、6、12 小时，默认 6 小时；只统计，不移动文件。
- 按类别和日期扫描指定缓存子目录，查看文件路径、大小和风险理由；文件默认不选，支持全选/全不选，二次确认后移到废纸篓。运行中的应用标为高风险，另行确认后支持强制移动已选文件。类别“全选”只决定扫描范围。
- 读取所选文件夹第一层的普通 `.dmg`、`.pkg` 文件，核对包内应用标识与版本；不会运行安装程序。
- 下载安装包默认不选，支持全选/全不选；只在用户选择并再次确认后移到废纸篓。不卸载应用，也不自动清空废纸篓。
- 本地通知和登录启动可选；没有主动上传文件或扫描结果的功能。

### 下载与安装

**1.0.0-beta.3 公开测试版已发布。** 点击页面顶部的 DMG 下载入口，或前往[此版本的发布页](https://github.com/Dimoo-rich/MacSpaceGuard/releases/tag/v1.0.0-beta.3)，下载 `MSG-1.0.0-beta.3-AppleSilicon.dmg`。GitHub 自动生成的 **Source code** 压缩包不是安装包。

此版本仅临时本地签名，**未经 Developer ID 签名或 Apple 公证**，首次打开可能被 macOS 阻止；不保证每台 Mac 都能授权打开。请先阅读[安装说明](docs/INSTALL.md)，不要关闭系统安全保护。

### 检查更新（beta.3 起）

新增“检查更新”、可选的每日检查（默认关闭）和正式版/测试版频道。发现新版展示更新说明，再由用户去官方发布页下载替换；不自动安装。网络失败不影响扫描清理。旧 beta.2 用户需先手动下载安装一次新版本。详见 [更新说明](docs/UPDATES.md) 与 [隐私说明](docs/PRIVACY.md)。

更新时先退出旧版，将新版拖入“应用程序”并选择**替换**，不要选择“保留两者”；安装后推出 DMG。防重复启动不会自动删除其他目录中的旧应用，安装包与备份也不会自动删除。

### 风险与边界

只扫描白名单子目录，不扫描整个资源库，不处理 Application Support、Containers、Logs、聊天数据库、浏览器密码或文稿。缓存风险等级是用途提示，不是安全删除保证；各类别真实应用可用性、离线和重建影响仍待验证。建议先退出相关应用，再核对文件与风险理由。不确定的文件请保留。

安装包标识匹配不证明来源可信，也不证明已安装应用来自这个包。“未找到”不等于从未安装。扫描和移动期间请勿同时下载、替换或修改所选文件；虽然移动前会校验文件身份、大小和日期，最后检查与系统移动之间仍存在非原子的竞争窗口。

移到废纸篓仍占用空间，用户自行检查并清空后才会腾出空间；清空前可尝试“放回原处”，但恢复不保证撤销已发生的影响。MSG 不会直接释放运行内存。

[清理范围](docs/CLEANUP_SCOPE.md) · [隐私说明](docs/PRIVACY.md) · [验收与剩余风险](docs/SAFETY_AUDIT.md) · [版本记录](CHANGELOG.md)

### 反馈

到 [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues) 填写版本、M 系列芯片、macOS 版本、操作步骤和完整提示。可参考[反馈模板](docs/FEEDBACK.md)。这是手动反馈，不会自动生成或上传诊断报告。截图请隐去用户名和私人文件名。

## English

MSG is a lightweight macOS menu bar app for monitoring memory and disk space, managing allowlisted caches, and organizing downloaded installers. Scanning and file operations are local; beta.3 adds optional online update checking.

**Public download: 1.0.0-beta.3 (public beta, not stable).** Apple Silicon only; Chinese UI. The build deployment minimum is macOS 13, but the oldest OS and a second Mac remain untested. This is not a verified macOS 13+ compatibility promise.

- Scheduled checks every 1, 3, 6 or 12 hours (default: 6) only report findings.
- Cache files start unselected. Review their paths and risk reasons, explicitly select files (or all), then confirm moving to Trash. Running-app caches require an additional explicit confirmation; force-moving never bypasses protected paths or file validation.
- Installer scanning reads metadata from first-level regular DMG/PKG files without running installers.
- Installer selection starts empty; all/none controls only change selection. Explicit confirmation is required to move files to Trash. MSG never uninstalls apps or empties Trash.
- No automatic uploads of files or findings.

**Starting with beta.3:** manual update checks, opt-in daily checks (off by default), and stable/prerelease channels. Release notes are shown before opening the official download page; no automatic downloads or installation. Existing beta.2 users need a manual replacement first. Checks contact GitHub without uploading files or scan results. See [updates](docs/UPDATES.md) and [privacy](docs/PRIVACY.md).

**The 1.0.0-beta.3 public beta is available.** Use the DMG download link at the top of this page, or download `MSG-1.0.0-beta.3-AppleSilicon.dmg` from [this release](https://github.com/Dimoo-rich/MacSpaceGuard/releases/tag/v1.0.0-beta.3). GitHub's **Source code** archives are not installers. The build uses ad-hoc signing without Developer ID or Apple notarization and may be blocked on first launch. Read the [installation guide](docs/INSTALL.en.md).

Bundle-ID matches do not establish installer authenticity or provenance. Not-found does not prove never-installed. Cache risk labels do not guarantee safety; real-app, offline and rebuild effects remain unverified. Do not concurrently modify selected cache files or installers: identity/size/date checks are not atomic with the system Trash operation. Moving to Trash does not immediately free space; users decide whether and when to empty it. Recovery cannot guarantee undoing prior effects.

Report problems via [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues); redact private filenames and paths. Feedback is manual, not an automatic diagnostic upload.

## Development / 本地开发

Requires Apple Silicon and Swift 6 tools. Full XCTest requires Xcode; the self-test uses UUID temporary fixtures and simulated Trash, never real caches. CI success does not replace second-Mac installation acceptance.

```sh
swift run --disable-sandbox MacSpaceGuardSelfTest
swift test --disable-sandbox
./scripts/package_app.sh
./scripts/create_dmg.sh
```

Build output: `dist/.build.noindex/MacSpaceGuard.app` and `dist/MacSpaceGuard.dmg`. The `.noindex` directory is build staging, not another installation. Install into Applications, keep old versions as ZIP backups, and archive test bundles after use. See [distribution notes](docs/DISTRIBUTION.md).

## License

[MIT License](LICENSE).
