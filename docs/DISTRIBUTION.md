# 发布与安装方案

当前构建为 **1.0.0-beta.1 公开测试版**，Apple Silicon only。零预算、临时本地签名，未经 Developer ID 签名或 Apple 公证。GitHub 提供源码和准备好的 Release 附件；小红书仅介绍开发和使用过程，不把此原生 Mac App 上传为网页小工具或 Red Skill。

## 发布顺序

1. 固定测试版范围：缓存只读；下载安装包逐项确认后移到废纸篓。核心缓存移动 API 同样拒绝调用，不仅是隐藏按钮。
2. 执行自动测试、检查包内容、arm64 架构、签名、DMG 和校验值；记录通过与未覆盖项。
3. 先创建 Release 草稿，标题和标签均为 1.0.0-beta.1，勾选 Pre-release。上传 DMG、SHA256.txt 和说明。用户确认后发布，不将其标为稳定 Latest。
4. 从实际发布链接重新下载，核对 SHA-256；不要把源码压缩包当安装包。
5. 另一台 M 系列 Mac 测试后，再考虑稳定 1.0.0。修复后的包使用新版本，不覆盖已发布同版本附件。

## 构建

```sh
./scripts/package_app.sh
./scripts/create_dmg.sh
shasum -a 256 dist/MacSpaceGuard.dmg
```

应用的 CFBundleShortVersionString 使用数值 1.0.0；MSGReleaseVersion 和“关于”显示完整的 1.0.0-beta.1。构建号为 22。展示和 Release 必须保留 beta 标识，不能据数值字段冒称稳定版。

现有 CI 运行 XCTest、自检与打包，不自动创建 Release。成功不等于首次下载、其他设备或 Apple 信任验收。适用范围、临时签名限制、恢复方式和反馈入口必须随下载提供，不要求关闭 Gatekeeper 或 SIP。

## 稳定 1.0.0 尚缺

- 另一台 Mac 最终下载包的首次安装、授权、菜单栏、升级、通知及登录启动验证。
- 最低系统实测，或收窄对外支持承诺。
- 对未来要开放的每条缓存移动规则验证应用可用性及离线、重建影响；重新审查移动竞态。未验证的类别保持只读。
- 安装包最终检查与 Trash 的非原子窗口进一步审查、合理防护；目前明确披露而未宣称解决。
- 无未经确认移动、越界、误移动、无法启动等未解决阻塞问题。

是否付费不决定版本号；尚缺的验证也不会因改版本号而消失。

安装说明：[中文](INSTALL.md) · [English](INSTALL.en.md)。[发布说明草稿](RELEASE_1_0_0_BETA_1.md) · [验收记录](BETA_1_ACCEPTANCE.md)。
