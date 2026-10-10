# Installing MSG

[中文](INSTALL.md)

**1.0.0-beta.2 is a public beta, not stable.** Second-Mac installation, first downloaded launch and minimum-OS compatibility remain pending.

## Requirements and installation

Apple Silicon only; Chinese UI. The build deployment minimum is macOS 13, not a verified compatibility promise. See [acceptance](BETA_2_ACCEPTANCE.md) for the tested environment.

1. Visit [Releases](https://github.com/Dimoo-rich/MacSpaceGuard/releases), find 1.0.0-beta.2 marked Pre-release. No DMG means it has not been published yet.
2. Download `MSG-1.0.0-beta.2-AppleSilicon.dmg` and `SHA256.txt`. GitHub's Source code archives are not installers.
3. Open the DMG and drag MacSpaceGuard to Applications. Quit and keep a ZIP backup of an existing version before replacing it. Do not keep multiple extracted apps running in parallel.
4. Launch from Applications, not the DMG or Downloads, and eject the DMG after installation. Controls appear in the menu bar, not the Dock. Development and test copies may appear in application searches; keep backups compressed.
5. Notifications and launch-at-login are optional. Scheduled checks default to six hours and never move files.

## Future updates

The public beta.2 requires manually checking Releases. Locally prepared beta.3 adds manual update checks and opt-in daily notifications; existing users must replace beta.2 once to get this feature. Updates still require quitting/backing up the old app and replacing it through Finder. No automatic installation. See [updates](UPDATES.md).

## Security prompts

The build uses ad-hoc signing without Developer ID or Apple notarization. Signature verification is not Apple approval; macOS may block first launch.

Only if you trust the official download, believe it has not been tampered with and understand the risk, follow [Apple's instructions](https://support.apple.com/en-us/102445) to decide whether to open it. After attempting launch, check System Settings → Privacy & Security for Open Anyway. Availability depends on OS and device management.

Do not disable system-wide protection. If macOS reports malware, damage, or no authorization option, stop and report it rather than forcing removal of restrictions.

## First trial, Trash and feedback

You can test installation and viewing without moving any real files. Cache and installer moving requires explicit selection and a second confirmation. Running-app caches need an additional confirmation; force-moving applies only to reviewed cache files, never protected paths, cache indexes, symlinks or changed files. Risk labels do not guarantee safety; quit related apps first when possible. Do not concurrently download, modify or replace selected files. Metadata matching does not authenticate an installer.

Moving cache files and installers to Trash does not free space immediately. MSG never empties Trash. Review its contents before deciding to empty it. Finder's Put Back may restore files before emptying; restoration does not guarantee undoing prior effects.

Use the [feedback template](FEEDBACK.md) and [Issues](https://github.com/Dimoo-rich/MacSpaceGuard/issues), or manually send feedback to the publisher. No diagnostic report is automatically generated or uploaded. Redact private filenames and paths.
