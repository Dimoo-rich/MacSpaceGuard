# Installing MSG

[中文](INSTALL.md)

**1.0.0-beta.1 is a public beta, not stable.** Second-Mac installation, first downloaded launch and minimum-OS compatibility remain pending.

## Requirements and installation

Apple Silicon only; Chinese UI. The build deployment minimum is macOS 13, not a verified compatibility promise. See [acceptance](BETA_1_ACCEPTANCE.md) for the tested environment.

1. Visit [Releases](https://github.com/Dimoo-rich/MacSpaceGuard/releases), find 1.0.0-beta.1 marked Pre-release. No DMG means it has not been published yet.
2. Download `MSG-1.0.0-beta.1-AppleSilicon.dmg` and `SHA256.txt`. GitHub's Source code archives are not installers.
3. Open the DMG and drag MacSpaceGuard to Applications. Quit and back up an existing version before replacing it.
4. Launch from Applications; controls appear in the menu bar, not the Dock.
5. Notifications and launch-at-login are optional. Scheduled checks default to six hours and never move files.

## Security prompts

The build uses ad-hoc signing without Developer ID or Apple notarization. Signature verification is not Apple approval; macOS may block first launch.

Only if you trust the official download, believe it has not been tampered with and understand the risk, follow [Apple's instructions](https://support.apple.com/en-us/102445) to decide whether to open it. After attempting launch, check System Settings → Privacy & Security for Open Anyway. Availability depends on OS and device management.

Do not disable system-wide protection. If macOS reports malware, damage, or no authorization option, stop and report it rather than forcing removal of restrictions.

## First trial, Trash and feedback

You can test installation and viewing without moving any real files. **All caches are read-only in this beta**, including force-moving. Installer moving requires explicit selection and a second confirmation. Do not concurrently download, modify or replace selected installers. Metadata matching does not authenticate an installer.

Moving installers to Trash does not free space immediately. MSG never empties Trash. Review its contents before deciding to empty it. Finder's Put Back may restore files before emptying; restoration does not guarantee undoing prior effects.

Use the [feedback template](FEEDBACK.md) and [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues), or manually send feedback to the publisher. No diagnostic report is automatically generated or uploaded. Redact private filenames and paths.
