# 更新说明 / Updates

此功能从已公开发布的 **1.0.0-beta.3** 起提供。旧 beta.2 没有检查更新功能。老用户必须先手动下载安装一次带此功能的版本，不能通过修改 GitHub 页面给已安装的旧程序添加功能。

## 用户如何更新

1. 点菜单栏 MSG 图标，再点“检查更新”。“立即检查”仍是本机内存、磁盘与缓存统计，两者互不替代。
2. 有新版时，窗口显示当前版本、新版本、正式版/测试版标识与发布者的更新说明。可以点“稍后”；菜单保留“查看更新”入口。
3. 点“前往下载”打开官方 GitHub 发布页。先看系统要求、安装限制及风险，再下载 M 系列 Mac 的 DMG，不要下载 Source code 当安装包。
4. 先退出旧版，备份旧应用，再把新版拖入“应用程序”，选择“替换”而非“保留两者”，推出安装盘后打开。备份建议保持 ZIP，不会自动删除其他目录里的旧副本或安装包。可能仍遇到未经公证提示，按 [安装说明](INSTALL.md) 决定是否安装。更新检查并不代表 Apple 已验证该安装包。

## 每日提醒与频道

- “更新设置 → 每日检查更新”默认关闭。启用时说明网络访问并要求确认；应用运行时，每 24 小时最多启动一次自动查询，休眠或应用退出期间不保证准时执行。
- 检测到同一新版只发一次本地系统通知，不反复弹窗；即使未允许系统通知，应用菜单仍显示“发现新版”。关闭自动检查后不会继续定时请求，也不会清除已经显示的新版入口。
- 可选“仅正式版”或“正式版及测试版”。未保存选择时，测试版安装默认接收两种版本，正式版安装默认只接收正式版。切换频道仅修改本地偏好，下次手动/到期检查生效。
- 按版本号比较，不按发布日期比较；例如 beta.10 晚于 beta.2，1.0.0 正式版晚于 1.0.0-beta.3。不建议降级；同版本和更旧版本不提示。
- 仅提示已公开发布、提供已上传且非空的对应 Apple Silicon DMG 的新版。草稿、缺少安装包、错误链接不会成为可用更新。
- 不自动下载、不自动替换、不执行安装器、不关闭系统安全保护。网络失败显示“暂时无法检查”，不会谎报“已经是最新版”，不影响本地功能。

## 发布者需要做什么

每次发布必须同时更新代码中的版本、应用资源中的版本/构建号，并创建同版本的公开 Release，上传 `MSG-版本号-AppleSilicon.dmg` 和校验文件；正式版不勾 Pre-release，测试版要勾选。应用查询的是 Releases，而不是源码提交或普通 Git tag。更新说明来自 Release 正文，按普通文本展示，不自动执行或打开其中的链接。

先完成该版本验证，再公开发布；不要用未测试的包替换已有同版本附件。不能保证 GitHub 在所有网络环境可访问。网络范围、第三方可见信息和本地保存内容见 [隐私说明](PRIVACY.md)。

## English

Update checking starts with the published **1.0.0-beta.3** public beta. Existing beta.2 installations require one manual download/replacement before this feature is available.

Use **检查更新** (Check for updates) in the menu. Newer downloadable releases show their version, prerelease/full-release status and plain-text release notes. **前往下载** opens the official release page; MSG never downloads, installs or executes updates automatically. Quit and back up the old application before replacing it through Finder. Choose Replace, not Keep Both, then eject the DMG. Old installers and copies elsewhere are not automatically removed. System requirements, ad-hoc signing and first-launch restrictions still apply.

**每日检查更新** (Daily update checks) is opt-in and off by default. While the app runs, requests are initiated at least 24 hours apart, including failed attempts. Each detected version produces at most one local notification; the menu entry is visible even if system notifications are disabled. Select stable releases only or stable plus prereleases. Fresh beta builds default to both; stable builds default to stable only.

Only published newer releases with an uploaded, nonempty, matching Apple Silicon DMG and exact official HTTPS URLs qualify. SemVer ordering is used, not publication dates. Network failures never imply that the installed version is current. Local scanning and Trash operations do not depend on update access.

Checks fetch public GitHub release metadata without credentials, cookies, local files, filenames, scan results or telemetry. GitHub receives ordinary connection information including IP addresses. Opening the browser has its own privacy behavior. See [privacy](PRIVACY.md).
