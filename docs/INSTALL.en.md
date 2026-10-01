# Installing MSG

[中文](INSTALL.md)

Version 0.3.7 is a preview. Real Trash acceptance and installation on a second Mac remain pending. The repository currently provides source code; no public installer has passed release acceptance yet. These instructions describe the planned downloadable build.

## Requirements

The target is Apple Silicon Macs. The build deployment minimum is macOS 13, but the supported OS range must still be verified. Intel Macs are not supported. The app UI is currently in Chinese.

## Installation

1. Visit the project's [Releases](https://github.com/Dimoo-rich/MacSpaceGuard/releases). If there is no installer, a downloadable build has not been released yet.
2. Download `MacSpaceGuard.dmg` from a release's attachments. The automatically generated **Source code** archives are not installers.
3. Open the DMG and drag MacSpaceGuard to Applications.
4. Launch it from Applications. Its controls appear in the macOS menu bar; it does not stay in the Dock.
5. Choose whether to allow local notifications and launch at login. Scheduled checks default to every six hours and never move files.

## macOS security prompts

The zero-budget build uses ad-hoc signing, without Developer ID or Apple notarization. macOS may block the first launch. This limitation will be disclosed on the download.

Only if you trust the official download, believe it has not been tampered with, and understand the risks, follow [Apple's instructions](https://support.apple.com/en-us/102445) to decide whether to open it: after attempting to launch, check System Settings → Privacy & Security for **Open Anyway**, then confirm. Availability varies with macOS and device management policies.

Do not disable system-wide protection. If macOS identifies malware, reports a damaged app, or offers no authorization option, stop and report the problem instead of forcibly removing restrictions with terminal commands.

## Trash and recovery

MSG moves only selected, confirmed files to Trash. Moving them does not immediately free disk space; review Trash and empty it yourself when appropriate. MSG never empties Trash.

Quit related apps before moving their caches. To restore a file before emptying Trash, quit the related app and use Finder's **Put Back** action where available, or restore it to its original path. Recovery does not guarantee undoing effects already experienced by an app. Emptying Trash removes this recovery option.

Report problems in [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues), including app and OS versions and reproduction steps. Redact private filenames and paths from screenshots.
