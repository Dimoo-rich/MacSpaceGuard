# MSG 1.0.0-beta.2 · 公开测试版草稿 / Public beta draft

尚未公开发布。这是公开测试版，不是稳定 1.0.0。beta.1 只读方案已撤回，不能发布或沿用其安装包。

## 下载文件（发布完成后）

- `MSG-1.0.0-beta.2-AppleSilicon.dmg`：M 系列 Mac 安装包。
- `SHA256.txt`：最终安装包校验值。
- GitHub 自动生成的 Source code zip/tar.gz 是源码，不是安装包。

## 功能

- 菜单栏查看内存、交换空间及磁盘余量；定时检查只统计，不自动清理。
- 白名单缓存按类别和日期扫描，逐文件选择、全选/全不选，二次确认后移到废纸篓。
- 运行中的应用缓存标为高风险，可先退出应用，或额外确认后强制移动已选文件；强制确认不能绕过禁止路径、索引文件、符号链接或文件变化检查。
- 读取下载安装包 DMG/PKG 的应用元数据，不运行安装程序；主动选择并再次确认后可移到废纸篓，不卸载应用。
- 不永久删除或自动清空废纸篓。移到废纸篓后仍占用空间，需用户自行检查并清空才会释放。

## 限制与风险

仅 Apple Silicon，中文界面。编译最低 macOS 13，但最低系统和另一台 Mac 尚未实测。临时本地签名，未经 Developer ID 签名或 Apple 公证，首次打开可能被系统阻止；不要关闭系统安全保护。

缓存风险等级不是安全保证。各类别真实应用、离线和重建影响尚未充分验证，移走缓存仍可能造成应用异常或重新下载。建议先退出相关应用，保留不确定的文件；清空废纸篓前可尝试恢复，但恢复不保证撤销已发生的影响。

文件身份、大小、日期检查与系统 Trash 非原子；不要在扫描和移动期间同时修改或替换所选文件。安装包身份匹配也不能证明来源可信或安装来源。

反馈为手动提交，不自动生成或上传诊断报告。请隐藏私人信息。[安装说明](INSTALL.md) · [反馈模板](FEEDBACK.md) · [实际验收与未覆盖项](BETA_2_ACCEPTANCE.md)

## English

Public beta draft, not stable and not yet published. Apple Silicon only, Chinese UI. macOS 13 is the deployment minimum, not a tested compatibility promise. Ad-hoc signing only, without Developer ID or Apple notarization.

Cache files start unselected. Users review paths and risk reasons, select individual files or all, and confirm moving to Trash. Running-app caches need additional confirmation; force-moving cannot bypass protected directories, index files, symlinks or changed files. Downloaded DMG/PKG installers follow an explicit selection and confirmation workflow without running installers or uninstalling applications.

MSG never permanently deletes user files or empties Trash. Risk labels and confirmation do not guarantee safety; real-app, offline and rebuild effects remain unverified. Restoration cannot guarantee undoing prior effects. Final file checks and system Trash are not atomic; do not concurrently modify selected files. Feedback is manual with private data redacted. See the acceptance record for actual results and outstanding checks.
