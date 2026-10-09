# MSG 1.0.0-beta.1 · 公开测试版 / Public beta

**已撤回，未公开发布。此页仅保留旧草稿，禁止用于发布。当前草稿见 [beta.2](RELEASE_1_0_0_BETA_2.md)。**

这是公开测试版，不是稳定 1.0.0。可以先验证安装与查看，不要求试删真实文件。

## 下载哪个文件

- `MSG-1.0.0-beta.1-AppleSilicon.dmg`：M 系列 Mac 安装包。
- `SHA256.txt`：安装包校验值。
- GitHub 自动生成的 Source code zip/tar.gz 是源码，不是安装包。

## 本次功能范围

- 菜单栏查看系统内存、交换空间与磁盘余量；定时检查只统计。
- 按类别和时间查看指定旧缓存、文件路径、大小和风险。**所有缓存只读，暂不支持移动，包括强制移动。** 各应用缓存仍需使用验证。
- 查看下载的 DMG/PKG 包内应用及本机安装线索；不会运行安装程序。安装包可选择、全选/全不选并二次确认后移到废纸篓，不卸载应用。
- MSG 不清空废纸篓。移到废纸篓后仍占用空间，需要用户自行检查并清空才会释放。

## 安装与已知限制

仅 Apple Silicon；中文界面，不支持 Intel。编译最低 macOS 13，但最低系统及另一台 Mac 尚未验证，不承诺整个 macOS 13+ 范围已兼容。

**临时本地签名，未经 Developer ID 签名或 Apple 公证。** 首次打开可能被 macOS 阻止，不能保证所有电脑可授权。先读[安装说明](https://github.com/Dimoo-rich/MacSpaceGuard/blob/main/docs/INSTALL.md)，不要关闭系统安全保护。

安装包身份匹配不证明来源可信，也不证明当前应用来自此包。文件移动前检查身份、大小和日期，但最后检查与系统 Trash 仍非原子操作；不要同时下载、替换或修改所选文件。恢复不保证撤销已发生的影响。清理磁盘不等于释放运行内存。

反馈是手动提交，没有自动上传诊断报告。请在 [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues) 提供版本、芯片、系统版本、步骤和提示，隐藏私人信息。[验收与未覆盖项](https://github.com/Dimoo-rich/MacSpaceGuard/blob/main/docs/BETA_1_ACCEPTANCE.md)

## English

Public beta, not stable. Apple Silicon only, Chinese UI. macOS 13 is the build deployment minimum, not a verified compatibility promise; oldest OS and second-Mac testing remain pending.

**Caches are read-only**, including force-moving. Downloaded first-level DMG/PKG installers can be selected and moved to Trash only after explicit confirmation. No installer execution, uninstalling or emptying Trash. Moving to Trash does not immediately free disk space.

Ad-hoc signing only: **no Developer ID or Apple notarization**. First launch may be blocked. Read the [installation guide](https://github.com/Dimoo-rich/MacSpaceGuard/blob/main/docs/INSTALL.en.md); do not disable system-wide protection.

Metadata matches do not authenticate an installer. Final identity/size/date checks and system Trash are not atomic: do not concurrently modify or replace selected files. Feedback is manual through Issues, with private data redacted. See the acceptance record for actual results and pending checks.
