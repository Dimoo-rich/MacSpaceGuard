# 发布与安装方案

当前版本为 0.3.7 预览版，Apple Silicon 为目标平台；尚未完成真实废纸篓、另一台 Mac 和最低系统的发布验收。目前先公开源码，不发布稳定安装包。

## 零预算路线

使用 [GitHub 仓库](https://github.com/Dimoo-rich/MacSpaceGuard)存放源码、问题反馈和版本记录；通过 Releases 附件提供后续验收过的 DMG。下载安装包不要求会使用 Git 或编译源码，也不要求拥有 GitHub 账号。

此路线不办理 Apple 付费会员，不使用 Developer ID 签名或公证。应用仍使用本地临时签名（ad-hoc）；它不证明发布者身份，也不等于 Apple 公证。

需要在下载页明确标注未经公证、适用系统和首次打开的可能限制。只按 Apple 官方支持流程说明用户如何自行判断和授权，不提供关闭 Gatekeeper、SIP 或强制移除下载隔离属性的命令。未经公证会增加安装门槛；不保证在受管理的 Mac 或所有系统上可运行。

普通用户安装说明见 [INSTALL.md](INSTALL.md)，英文见 [INSTALL.en.md](INSTALL.en.md)。

## 构建与测试

```sh
./scripts/package_app.sh
./scripts/create_dmg.sh
shasum -a 256 dist/MacSpaceGuard.dmg
```

现有 GitHub Actions 在 Mac runner 上运行完整单元测试、自带临时文件自测，并生成预览 DMG。CI 工件不是稳定 Release，测试通过也不能代替真实 Trash 和首次安装验收。CI 不自动公开发布 Release。

## 1.0 放行条件

- 完整测试与正常用户环境下的移入废纸篓、恢复、取消、权限失败提示均通过。
- 每条启用的缓存规则已核对对应应用版本；扫描与移动之间的路径变化风险已审查并合理处理。
- 在另一台 M 系列 Mac 上验收下载、首次打开的系统提示、安装、升级、通知、登录启动和清理交互。最低 macOS 版本须实测，或收窄承诺的支持范围。
- 小范围试用没有未解决的误移动、越界移动、未经确认移动、无法启动等阻塞问题。
- 下载附件清楚标明版本、架构、未经公证限制；从实际下载链接取回的最终文件与发布的 SHA-256 一致。
- 安装说明、隐私、清理范围、更新记录和反馈入口齐全。

不付费不阻止版本号升为 1.0；缺少必要验收仍然阻止放行。不能把临时签名校验成功描述成 Gatekeeper 信任或 Apple 公证通过。

## 未来可选：Developer ID 与公证

如果以后决定改善普通用户的安装体验，可使用 Apple Developer Program 的 Developer ID 证书签名，并提交公证和附票。这是未来付费选项，不是当前计划的前置步骤。

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Name (TEAMID)" ./scripts/package_app.sh
./scripts/create_dmg.sh
NOTARY_PROFILE="macspaceguard-notary" ./scripts/notarize.sh
```

证书私钥、公证凭据和账户密码不能提交进仓库。公开上传前检查文件清单，只包含源码、资源、文档、许可与构建配置；安装包作为 Release 附件，不进入源码历史。对外发布后不覆盖同版本附件，修改使用新版本号。

官方参考：[GitHub 仓库](https://docs.github.com/en/repositories/creating-and-managing-repositories/about-repositories)、[GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)、[Apple 安全打开 App](https://support.apple.com/zh-cn/102445)、[Developer ID](https://developer.apple.com/developer-id/)。
