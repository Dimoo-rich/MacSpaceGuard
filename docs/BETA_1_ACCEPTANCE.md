# MSG 1.0.0-beta.1 发布准备验收（2026-10-09）

**此只读方案已按用户要求撤回，未公开发布安装包，不作为当前产品范围。** 下面保留历史测试事实；当前修正版见 [beta.2 验收记录](BETA_2_ACCEPTANCE.md)，不得将此版 CI 通过视为 beta.2 已通过。

状态：本地构建和独立自检通过；GitHub CI 的 13 项 XCTest、自检、打包和 DMG 生成通过。下载校验、DMG CRC、最终镜像挂载及镜像内 App 签名与版本检查通过，最终 GUI 交互检查仍待完成。尚未发布安装包、替换已安装应用或清理真实缓存。此记录不得作为稳定 1.0.0 放行证明。

## 范围与防护

- 所有 10 个默认缓存类别只扫描和查看。缓存清单没有删除勾选或移动控制。
- 核心 CleanupService 不执行任何文件操作；即使直接调用、提供全部运行中规则确认，仍返回 0 移动、0 字节及只读原因。不依赖用户偏好设置或环境变量开关。
- 下载安装包功能保留：第一层普通 DMG/PKG、内容元数据核对、默认不选、全选/全不选、取消优先的二次确认和系统 Trash。
- 无永久删除用户文件、自动清空废纸篓或运行安装程序入口。
- 关于窗口使用完整 beta 版本；plist 数值版本 1.0.0、MSGReleaseVersion 为 1.0.0-beta.1、构建 22。

## 本轮已执行

| 项目 | 结果 |
| --- | --- |
| release 构建与 App 签名验证 | 通过 |
| 独立 SelfTest | 通过；仅 UUID 临时测试文件和模拟废纸篓 |
| 本机完整 XCTest | 未运行成功：只有 Command Line Tools，缺少 XCTest 模块；不能算通过 |
| 缓存不可移动 | 自检验证普通及运行中额外确认请求仍被拒绝；新增 XCTest 覆盖全部默认规则且断言不调用 Trash |
| 安装包边界及变化校验 | 自检通过，包括目录外、符号链接、修改后和同大小日期不同身份的替换文件；不会移动这些测试文件 |
| beta GUI | 解锁后 Finder 操作与截图恢复，已从最终 CI 镜像启动 App；活动监视器确认路径为 /Volumes/MacSpaceGuard/MacSpaceGuard.app，进程取样显示已进入 NSApplication 事件循环。连接菜单栏 App 仍超时，待用户打开“资源库缓存查看”窗口后继续，不将启动或旧版 GUI 结果算作交互验收通过 |
| 本机生成 DMG | 受限执行环境 hdiutil create 返回设备未配置；未将失败算作通过，改取 CI 生成的包 |
| CI XCTest、打包与 DMG | 全部通过；源提交 5173c5abf7397c09d9e0aba3debea21453295285，run 37878689155 |
| 取回 CI 工件 | 压缩包 SHA-256 与 GitHub 官方 artifact digest 完全一致 |
| DMG 完整性 | hdiutil verify 所有 CRC 通过；Finder 成功挂载最终只读 CI 镜像，hdiutil info 确认来源路径；镜像内 App 的 codesign --verify --deep --strict 通过，file 确认 arm64，plist 确认完整 beta 元数据和构建 22 |

CI：[测试与打包](https://github.com/Dimoo-rich/MacSpaceGuard/actions/runs/37878689155)。工件 ID 11594030439。压缩包通过 nightly.link 的公开下载重定向取回，无登录、无安装服务或授予权限；使用 GitHub 官方公开 API 给出的摘要校验后才解压。压缩包摘要：`6085e8e6ace52c3f808fb567e4ffbaac9a739c2fa101d0bfe5900f49f2e53beb`。

最终 DMG 1,662,787 字节，SHA-256：`b02f0bef4c1102fa5157ea7a2ad09860a5b195e0a2c1427e3638de7b8c19e5b2`。改名为 MSG-1.0.0-beta.1-AppleSilicon.dmg 后摘要保持一致。已验证本地构建与最终 CI 镜像内 App 的 arm64、构建 22、完整 beta 元数据及 ad-hoc 签名；最终界面交互仍待检查。此次本地文件没有 quarantine 属性，因此不能作为其他用户从浏览器下载后的 Gatekeeper 首次打开验证。

本机环境：Apple Silicon arm64，macOS 27.0.1（26A434），Swift 6.4，打包使用兼容的 macOS 26.5 SDK。编译最低 macOS 13 不等于兼容性已验证。

此前 0.3.7 的本机安装包 GUI 和缓存独立副本 GUI 覆盖过选择、取消、真实系统 Trash、Finder 恢复及变化跳过；缓存权限失败也通过。它们是历史证据，不替代 beta 新界面、第二台 Mac 或真实缓存规则验证。

## 仍未覆盖与已知风险

1. 另一台 M 系列 Mac 的最终 DMG 首次安装、系统提示、升级、通知和登录启动，以及最低系统兼容性。
2. 缓存规则的真实应用、离线与索引重建影响；因此所有缓存移动关闭。
3. 安装包最后身份/大小/日期检查和系统 Trash 非原子，其他进程恰好替换路径仍可能误移动。暂以限定范围、选择确认、变化跳过、Trash 和明确披露降低风险，不声称原子问题已修复。
4. 未经 Developer ID 签名或 Apple 公证，其他设备可能阻止首次打开；不能保证可授权。
5. 发布后的实际下载附件尚未取回核对 SHA-256，须在 Release 发布后补验。

公开测试标签不保证安全。用户可以只测试安装和查看；不要求清理任何真实文件。稳定版需重新审核未验证范围及未解决问题。
