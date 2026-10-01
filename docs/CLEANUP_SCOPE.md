# MacSpaceGuard 清理范围（0.3.7）

## 资源库三个大目录的覆盖情况

| 目录 | 当前处理方式 |
| --- | --- |
| `~/Library/Application Support` | 不扫描、不清理；其中可能混有账户、聊天数据库和其他应用数据。 |
| `~/Library/Containers` | 不扫描、不清理；沙盒容器可能含应用持久数据。 |
| `~/Library/Caches` | 只扫描下表列出的白名单子目录，不做整目录扫描。 |
| `~/Library/Logs` | 0.3.0 起不再纳入扫描或清理；旧版整目录规则过宽。 |

菜单中的“在访达中打开资源库”只打开 `~/Library`，不代表上述三个目录都已完成扫描。

## 当前白名单

自动检查只统计，不移动文件，且跳过运行中应用的缓存目录。手动清理时，用户必须选择目录、选择“早于此日期”的截止日、逐文件核对并选择，再确认清单。仅将白名单目录内、修改时间早于截止日的普通文件移到废纸篓；若对应应用仍在运行，还会单独显示风险，只有用户明确选择“仍要移到废纸篓”才处理该目录。风险等级是提示，不是零风险保证。默认自动检查采用下表的保留期；手动选择日期时，以所选日期为准。

| 类别 | 缓存目录（相对用户主目录） | 默认保留期 |
| --- | --- | ---: |
| ChatCut 更新缓存 | `Library/Caches/chatcut-desktop-updater` | 7 天 |
| ChatCut 安装残留 | `Library/Caches/io.chatcut.desktop.ShipIt` | 7 天 |
| Coze 更新缓存 | `Library/Caches/coze-updater` | 7 天 |
| Google 更新缓存 | `Library/Caches/com.google.SoftwareUpdate` | 14 天 |
| Homebrew 下载缓存 | `Library/Caches/Homebrew` | 14 天 |
| Node 编译缓存 | `Library/Caches/node-gyp` | 30 天 |
| Python 下载缓存 | `Library/Caches/pip` | 30 天 |
| Chrome 网页缓存 | `Library/Caches/Google/Chrome/Default/Cache/Cache_Data` | 30 天 |
| 微信 WebKit 网络缓存 | `Library/Caches/com.tencent.xinwechat2/WebKit/NetworkCache` | 30 天 |
| 微信安装更新缓存 | `Library/Caches/com.tencent.xinWeChat/org.sparkle-project.Sparkle/Installation` | 30 天 |

Chrome 目前只覆盖 `Default` 配置文件的网页缓存，不覆盖其他 Chrome 配置文件。微信的两个目录分别属于不同版本/安装形式；本机未找到的目录不会扫描。缓存被清理后，应用可能需要重新下载或生成部分内容。

“早于昨天”（T-1）只表示文件修改时间较早，不能证明运行中的应用不再引用它。Chrome 等缓存还包含索引和后台读写。建议退出应用后清理；即使只移到废纸篓，运行中的应用也可能出现缓存重建、异常或重新下载。此操作不会扩大白名单范围，也不会移动聊天数据库、书签、密码等非缓存数据。

不会清理整个 `~/Library/Caches`、`Application Support`、`Containers`、`Logs`、Chrome 的用户资料/Cookie/书签/密码、微信聊天数据库及附件/下载文件、飞书数据、iCloud、文稿、桌面或废纸篓。不会跟随符号链接进入其他位置，也不会移动目录本身。`salt`、`index` 等缓存元数据文件会跳过。缓存与安装包均只移到废纸篓；用户可以恢复，但需要自行清空废纸篓才会腾出磁盘空间，MSG 不会自动清空。

## 下载的安装包

单独的“清理下载的安装包”功能默认扫描 `~/Downloads` 第一层的普通 `.dmg`、`.pkg` 文件，也可选择其他文件夹。DMG 临时只读挂载且不打开访达，PKG 临时展开以读取元数据；不会执行安装程序或脚本。程序从包内提取应用 Bundle ID 和版本，再与常见应用目录及系统应用登记对照，并直接显示包内应用和易懂的识别结果。引导安装器、文件名与内容不符或无法识别的文件会单独提示。未找到应用仅代表上述位置未找到；找到应用也不证明它来自这个安装包，更不证明安装包来源可信。不会按文件名猜测安装状态。

安装包不会自动移除。用户必须逐个勾选，并在再次确认后才会移到废纸篓；这不会卸载应用。文件变化、符号链接、目录外文件或非 `.dmg`/`.pkg` 会被跳过。`.zip` 可能包含文档或其他资料，当前不纳入安装包检查。

“在访达中打开资源库”只打开 `~/Library`，不会自动选中或删除任何文件。资源库中还有许多并非缓存的数据，手动删除前应确认用途并保留备份。
