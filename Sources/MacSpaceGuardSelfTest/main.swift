import Foundation
import MacSpaceGuardCore

if CommandLine.arguments.contains("--scan-home") {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    let reports = CacheScanner().scan()
    for report in reports where report.reclaimableBytes > 0 {
        print("\(report.rule.displayName): \(formatter.string(fromByteCount: report.reclaimableBytes))")
    }
    let total = reports.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
    print("Total: \(formatter.string(fromByteCount: total))")
    exit(0)
}

if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--inspect-installers" {
    do {
        let findings = try InstallerScanner().scan(directory: URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true))
        for finding in findings {
            print("\(finding.url.lastPathComponent): \(finding.evidence.title) — \(finding.evidence.explanation)")
        }
        exit(0)
    } catch {
        fputs("安装包检查失败：\(error)\n", stderr)
        exit(1)
    }
}

enum SelfTestError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SelfTestError.failed(message) }
}

do {
    let parsed = SystemMonitor.parseSwapUsage(
        "total = 8192.00M  used = 3177.50M  free = 5014.50M"
    )
    try require(parsed == 3_331_850_240, "交换空间解析失败")
    try require(
        SystemMonitor.parseMemoryFreePercentage("System-wide memory free percentage: 30%") == 30,
        "内存余量解析失败"
    )

    let fileManager = FileManager.default
    let temporary = fileManager.temporaryDirectory
        .appendingPathComponent("MacSpaceGuardSelfTest-\(UUID().uuidString)", isDirectory: true)
    let cache = temporary.appendingPathComponent("Library/Caches/TestCache", isDirectory: true)
    try fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporary) }
    // Keep moved test files inside this UUID fixture; never use the user's real Trash.
    let fakeTrash = temporary.appendingPathComponent("FakeTrash", isDirectory: true)
    try fileManager.createDirectory(at: fakeTrash, withIntermediateDirectories: true)
    let cleaner = CleanupService(fileManager: fileManager, trashItem: { source in
        try fileManager.moveItem(at: source, to: fakeTrash.appendingPathComponent(source.lastPathComponent))
    })

    let oldFile = cache.appendingPathComponent("old.bin")
    let recentFile = cache.appendingPathComponent("recent.bin")
    try require(fileManager.createFile(atPath: oldFile.path, contents: Data(repeating: 1, count: 128)), "无法创建旧测试文件")
    try require(fileManager.createFile(atPath: recentFile.path, contents: Data(repeating: 1, count: 256)), "无法创建新测试文件")
    try fileManager.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -20 * 86_400)],
        ofItemAtPath: oldFile.path
    )

    let rule = CacheRule(
        id: "test",
        displayName: "Test",
        relativePath: "Library/Caches/TestCache",
        minimumAgeDays: 7
    )
    let scanner = CacheScanner()
    let blockedLogs = CacheRule(id: "logs", displayName: "Logs", relativePath: "Library/Logs", minimumAgeDays: 30)
    try require(scanner.safeRoot(for: blockedLogs, homeDirectory: temporary) == nil, "整个 Logs 目录仍可清理")
    try require(!CacheScanner.defaultRules.contains { $0.relativePath == "Library/Logs" }, "日志规则未移除")
    let reports = scanner.scan(rules: [rule], homeDirectory: temporary)
    try require(reports.count == 1, "扫描报告数量错误")
    try require(reports[0].candidates.map(\.url.lastPathComponent) == ["old.bin"], "保留期筛选失败")
    try require(reports[0].reclaimableBytes == 128, "空间统计错误")
    let olderCutoff = Date(timeIntervalSinceNow: -25 * 86_400)
    let olderReports = scanner.scan(rules: [rule], homeDirectory: temporary, cutoffDate: olderCutoff)
    try require(olderReports[0].candidates.isEmpty, "自选截止日期没有生效")
    try require(
        !scanner.isSafeDescendant(
            URL(fileURLWithPath: "/tmp/cache-evil/file"),
            of: URL(fileURLWithPath: "/tmp/cache")
        ),
        "路径边界校验失败"
    )

    let protectedRule = CacheRule(
        id: "test",
        displayName: "Test",
        relativePath: "Library/Caches/TestCache",
        minimumAgeDays: 7,
        relatedBundleIdentifiers: ["com.example.running"]
    )
    let protectedReports = scanner.scan(rules: [protectedRule], homeDirectory: temporary)
    let skipped = cleaner.moveToTrash(
        reports: protectedReports,
        homeDirectory: temporary,
        runningBundleIdentifiers: ["com.example.running"]
    )
    try require(skipped.movedFiles == 0 && fileManager.fileExists(atPath: oldFile.path), "运行中的应用缓存没有被跳过")

    try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: oldFile.path)
    let changed = cleaner.moveToTrash(reports: reports, homeDirectory: temporary)
    try require(changed.movedFiles == 0 && fileManager.fileExists(atPath: oldFile.path), "扫描后变化的文件没有被跳过")
    try fileManager.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -20 * 86_400)],
        ofItemAtPath: oldFile.path
    )
    let refreshedReports = scanner.scan(rules: [rule], homeDirectory: temporary)
    let cleanup = cleaner.moveToTrash(reports: refreshedReports, homeDirectory: temporary)
    try require(cleanup.movedFiles == 0 && cleanup.originalBytes == 0, "公开测试版不应移动缓存")
    try require(cleanup.failures.first?.contains(ReleasePolicy.cacheReadOnlyExplanation) == true, "未说明缓存只读限制")
    try require(fileManager.fileExists(atPath: oldFile.path), "公开测试版移动了旧缓存")
    try require(!fileManager.fileExists(atPath: fakeTrash.appendingPathComponent(oldFile.lastPathComponent).path), "缓存进入了模拟废纸篓")
    try require(fileManager.fileExists(atPath: recentFile.path), "错误删除了新文件")

    let forceFile = cache.appendingPathComponent("force.bin")
    try require(fileManager.createFile(atPath: forceFile.path, contents: Data(repeating: 1, count: 64)), "无法创建运行中缓存测试文件")
    try fileManager.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -20 * 86_400)],
        ofItemAtPath: forceFile.path
    )
    let forceReports = scanner.scan(rules: [protectedRule], homeDirectory: temporary)
    let stillBlocked = cleaner.moveToTrash(
        reports: forceReports,
        homeDirectory: temporary,
        runningBundleIdentifiers: ["com.example.running"],
        confirmedRunningRuleIDs: ["wrong-rule"]
    )
    try require(stillBlocked.movedFiles == 0 && fileManager.fileExists(atPath: forceFile.path), "未经指定的运行中目录未被阻止")
    let forced = cleaner.moveToTrash(
        reports: forceReports,
        homeDirectory: temporary,
        runningBundleIdentifiers: ["com.example.running"],
        confirmedRunningRuleIDs: [protectedRule.id]
    )
    try require(forced.movedFiles == 0 && fileManager.fileExists(atPath: forceFile.path), "额外确认不应绕过测试版缓存只读限制")
    try require(!fileManager.fileExists(atPath: fakeTrash.appendingPathComponent(forceFile.lastPathComponent).path), "运行中缓存进入了模拟废纸篓")
    try require(fileManager.fileExists(atPath: recentFile.path), "错误移动了未到期文件")

    // All destructive checks below use files created inside this test's own
    // UUID-named temporary directory; no real Library or Downloads is touched.
    let outside = temporary.appendingPathComponent("Outside", isDirectory: true)
    try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
    let outsideFile = outside.appendingPathComponent("keep.bin")
    try require(fileManager.createFile(atPath: outsideFile.path, contents: Data(repeating: 2, count: 32)), "无法创建边界测试文件")
    let oldDate = Date(timeIntervalSinceNow: -20 * 86_400)
    try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: outsideFile.path)
    let link = cache.appendingPathComponent("outside-link.bin")
    try fileManager.createSymbolicLink(at: link, withDestinationURL: outsideFile)
    let linkScan = scanner.scan(rules: [rule], homeDirectory: temporary)
    try require(!linkScan.flatMap(\.candidates).contains { $0.url.lastPathComponent == link.lastPathComponent }, "扫描跟随了指向白名单外的符号链接")
    let forgedLink = CacheCandidate(url: link, bytes: 32, modificationDate: oldDate, ruleID: rule.id, fileIdentity: FileIdentity(url: outsideFile)!)
    let verifiedCacheRoot = scanner.safeRoot(for: rule, homeDirectory: temporary)!
    let forgedReport = CacheAreaReport(rule: rule, rootURL: verifiedCacheRoot, cutoffDate: Date(), reclaimableBytes: 32, candidates: [forgedLink])
    let blockedLink = cleaner.moveToTrash(reports: [forgedReport], homeDirectory: temporary)
    try require(blockedLink.movedFiles == 0 && fileManager.fileExists(atPath: outsideFile.path), "伪造的符号链接报告移动了白名单外文件")

    let linkedRoot = temporary.appendingPathComponent("Library/Caches/LinkedRoot")
    try fileManager.createSymbolicLink(at: linkedRoot, withDestinationURL: outside)
    let linkedRule = CacheRule(id: "linked", displayName: "Linked", relativePath: "Library/Caches/LinkedRoot", minimumAgeDays: 7)
    try require(scanner.safeRoot(for: linkedRule, homeDirectory: temporary) == nil, "符号链接缓存根目录没有被拒绝")

    let changedSize = cache.appendingPathComponent("changed-size.bin")
    try require(fileManager.createFile(atPath: changedSize.path, contents: Data(repeating: 3, count: 16)), "无法创建变化测试文件")
    try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: changedSize.path)
    let sizeReport = scanner.scan(rules: [rule], homeDirectory: temporary)
    let sizeCandidates = sizeReport.flatMap(\.candidates).filter { $0.url.lastPathComponent == changedSize.lastPathComponent }
    try require(sizeCandidates.count == 1, "变化测试文件没有被扫描；报告：\(sizeReport.flatMap(\.candidates).map(\.url.path))；目标：\(changedSize.path)")
    try Data(repeating: 4, count: 32).write(to: changedSize)
    try fileManager.setAttributes([.modificationDate: sizeCandidates[0].modificationDate], ofItemAtPath: changedSize.path)
    let changedReport = CacheAreaReport(rule: rule, rootURL: verifiedCacheRoot, cutoffDate: Date(), reclaimableBytes: 16, candidates: sizeCandidates)
    let blockedChange = cleaner.moveToTrash(reports: [changedReport], homeDirectory: temporary)
    try require(blockedChange.movedFiles == 0 && fileManager.fileExists(atPath: changedSize.path), "扫描后大小变化的文件没有被跳过")

    let replacedFile = cache.appendingPathComponent("replaced-same-metadata.bin")
    try require(fileManager.createFile(atPath: replacedFile.path, contents: Data(repeating: 5, count: 16)), "无法创建同元数据替换测试文件")
    try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: replacedFile.path)
    let replacementCandidate = scanner.scan(rules: [rule], homeDirectory: temporary)
        .flatMap(\.candidates).first { $0.url.lastPathComponent == replacedFile.lastPathComponent }!
    let originalMovedAside = cache.appendingPathComponent("original-moved-aside.bin")
    try fileManager.moveItem(at: replacedFile, to: originalMovedAside)
    try require(fileManager.createFile(atPath: replacedFile.path, contents: Data(repeating: 6, count: 16)), "无法创建替换后的测试文件")
    try fileManager.setAttributes([.modificationDate: replacementCandidate.modificationDate], ofItemAtPath: replacedFile.path)
    let replacementReport = CacheAreaReport(rule: rule, rootURL: verifiedCacheRoot, cutoffDate: Date(), reclaimableBytes: 16, candidates: [replacementCandidate])
    let blockedReplacement = cleaner.moveToTrash(reports: [replacementReport], homeDirectory: temporary)
    try require(blockedReplacement.movedFiles == 0 && fileManager.fileExists(atPath: replacedFile.path), "同大小同时间戳的替换文件没有被跳过")

    let rejectedFile = cache.appendingPathComponent("trash-failure.bin")
    try require(fileManager.createFile(atPath: rejectedFile.path, contents: Data([9])), "无法创建废纸篓失败测试文件")
    try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: rejectedFile.path)
    let rejectedCandidate = scanner.scan(rules: [rule], homeDirectory: temporary)
        .flatMap(\.candidates).first { $0.url.lastPathComponent == rejectedFile.lastPathComponent }!
    let rejectedReport = CacheAreaReport(rule: rule, rootURL: verifiedCacheRoot, cutoffDate: Date(), reclaimableBytes: 1, candidates: [rejectedCandidate])
    let failingCleaner = CleanupService(fileManager: fileManager, trashItem: { _ in
        throw NSError(domain: "SelfTestTrash", code: 1)
    })
    let rejected = failingCleaner.moveToTrash(reports: [rejectedReport], homeDirectory: temporary)
    try require(rejected.movedFiles == 0 && rejected.failures.count == 1 && fileManager.fileExists(atPath: rejectedFile.path), "移到废纸篓失败时原文件没有保留")

    let installerDirectory = temporary.appendingPathComponent("Downloads", isDirectory: true)
    try fileManager.createDirectory(at: installerDirectory, withIntermediateDirectories: true)
    let matchingInstaller = installerDirectory.appendingPathComponent("Google-Chrome-130.0-arm64.dmg")
    let unknownInstaller = installerDirectory.appendingPathComponent("Other.pkg")
    let ignoredArchive = installerDirectory.appendingPathComponent("photos.zip")
    try require(fileManager.createFile(atPath: matchingInstaller.path, contents: Data([1, 2])), "无法创建测试 DMG")
    try require(fileManager.createFile(atPath: unknownInstaller.path, contents: Data([3])), "无法创建测试 PKG")
    try require(fileManager.createFile(atPath: ignoredArchive.path, contents: Data([4])), "无法创建测试 ZIP")
    let installedApp = InstalledApplication(name: "Google Chrome", version: "131.0", url: URL(fileURLWithPath: "/Applications/Google Chrome.app"), bundleIdentifier: "com.google.Chrome")
    let installerInspector = TestInstallerInspector()
    let installerFindings = try InstallerScanner(inspector: installerInspector).scan(directory: installerDirectory, installedApplications: [installedApp])
    try require(installerFindings.count == 2, "安装包扫描范围错误")
    guard let chromeFinding = installerFindings.first(where: { $0.url.lastPathComponent == matchingInstaller.lastPathComponent }),
          let otherFinding = installerFindings.first(where: { $0.url.lastPathComponent == unknownInstaller.lastPathComponent }) else {
        throw SelfTestError.failed("安装包结果缺失：\(installerFindings.map { $0.url.lastPathComponent })")
    }
    if case .installed = chromeFinding.evidence {} else { throw SelfTestError.failed("应用标识匹配失败") }
    if case .cannotIdentify = otherFinding.evidence {} else { throw SelfTestError.failed("未知安装包状态识别失败") }
    let outsideTrashAttempt = InstallerTrashService().moveToTrash([chromeFinding], from: cache)
    try require(outsideTrashAttempt.movedFiles == 0 && fileManager.fileExists(atPath: matchingInstaller.path), "安装包删除范围校验失败")
    try Data([3, 4]).write(to: unknownInstaller)
    let changedInstallerAttempt = InstallerTrashService().moveToTrash([otherFinding], from: installerDirectory)
    try require(changedInstallerAttempt.movedFiles == 0 && fileManager.fileExists(atPath: unknownInstaller.path), "扫描后变化的安装包没有被跳过")
    let linkedInstaller = installerDirectory.appendingPathComponent("outside-link.dmg")
    try fileManager.createSymbolicLink(at: linkedInstaller, withDestinationURL: outsideFile)
    let nestedInstallerDirectory = installerDirectory.appendingPathComponent("Nested", isDirectory: true)
    try fileManager.createDirectory(at: nestedInstallerDirectory, withIntermediateDirectories: true)
    let nestedInstaller = nestedInstallerDirectory.appendingPathComponent("nested.dmg")
    try require(fileManager.createFile(atPath: nestedInstaller.path, contents: Data([7])), "无法创建嵌套安装包测试文件")
    let rescannedInstallers = try InstallerScanner(inspector: installerInspector).scan(directory: installerDirectory, installedApplications: [installedApp])
    try require(!rescannedInstallers.contains { $0.url.lastPathComponent == linkedInstaller.lastPathComponent || $0.url.lastPathComponent == nestedInstaller.lastPathComponent }, "安装包扫描越过第一层或跟随了符号链接")
    let replacementInstallerFinding = rescannedInstallers.first { $0.url.lastPathComponent == unknownInstaller.lastPathComponent }!
    let originalInstallerMovedAside = installerDirectory.appendingPathComponent("original-installer-moved-aside.pkg")
    try fileManager.moveItem(at: unknownInstaller, to: originalInstallerMovedAside)
    try require(fileManager.createFile(atPath: unknownInstaller.path, contents: Data([8, 9])), "无法创建替换后的安装包测试文件")
    try fileManager.setAttributes([.modificationDate: replacementInstallerFinding.modificationDate], ofItemAtPath: unknownInstaller.path)
    let blockedInstallerReplacement = InstallerTrashService().moveToTrash([replacementInstallerFinding], from: installerDirectory)
    try require(blockedInstallerReplacement.movedFiles == 0 && fileManager.fileExists(atPath: unknownInstaller.path), "同大小同时间戳的替换安装包没有被跳过")

    let figmaInstaller = installerDirectory.appendingPathComponent("Figma.dmg")
    let omniInstaller = installerDirectory.appendingPathComponent("OmniGrafflepjb_jb51.dmg")
    try require(fileManager.createFile(atPath: figmaInstaller.path, contents: Data([5])), "无法创建 Figma 测试包")
    try require(fileManager.createFile(atPath: omniInstaller.path, contents: Data([6])), "无法创建 Omni 测试包")
    let installedExamples = [
        InstalledApplication(name: "Figma", version: "116", url: URL(fileURLWithPath: "/Applications/Figma.app"), bundleIdentifier: "com.figma.Desktop"),
        InstalledApplication(name: "OmniGraffle", version: "7", url: URL(fileURLWithPath: "/Applications/OmniGraffle.app"), bundleIdentifier: "com.omnigroup.OmniGraffle7")
    ]
    let examples = try InstallerScanner(inspector: installerInspector).scan(directory: installerDirectory, installedApplications: installedExamples)
    guard let figmaFinding = examples.first(where: { $0.url.lastPathComponent == figmaInstaller.lastPathComponent }),
          let omniFinding = examples.first(where: { $0.url.lastPathComponent == omniInstaller.lastPathComponent }) else {
        throw SelfTestError.failed("引导包或文件名不符测试结果缺失：\(examples.map { $0.url.lastPathComponent })")
    }
    if case .bootstrapper(_, let app) = figmaFinding.evidence {
        try require(app?.name == "Figma", "Figma 引导包未关联已安装主应用")
        try require(figmaFinding.evidence.title == "已找到 Figma；此包是引导器", "Figma 引导包提示不清楚")
    } else { throw SelfTestError.failed("Figma 引导包分类失败") }
    if case .unexpectedContents(let identity, let app) = omniFinding.evidence {
        try require(identity.name == "CORE Keygen" && app?.name == "OmniGraffle", "包内应用与文件名不符识别失败")
        try require(omniFinding.evidence.title == "包内并非 OmniGraffle", "文件名与内容不符提示不清楚")
    } else { throw SelfTestError.failed("OmniGraffle 文件名不符分类失败") }

    let fixtureApp = temporary.appendingPathComponent("Fixtures/Example.app/Contents", isDirectory: true)
    try fileManager.createDirectory(at: fixtureApp, withIntermediateDirectories: true)
    let info = [
        "CFBundleIdentifier": "org.example.InstallerFixture",
        "CFBundleName": "Example",
        "CFBundleVersion": "9",
        "CFBundleShortVersionString": "1.2.3",
        "CFBundlePackageType": "APPL"
    ]
    let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try infoData.write(to: fixtureApp.appendingPathComponent("Info.plist"))
    let package = installerDirectory.appendingPathComponent("fixture.pkg")
    let packageBuilder = Process()
    packageBuilder.executableURL = URL(fileURLWithPath: "/usr/bin/pkgbuild")
    packageBuilder.arguments = ["--component", fixtureApp.deletingLastPathComponent().path, "--install-location", "/Applications", package.path]
    packageBuilder.standardOutput = FileHandle.nullDevice
    packageBuilder.standardError = FileHandle.nullDevice
    try packageBuilder.run()
    packageBuilder.waitUntilExit()
    try require(packageBuilder.terminationStatus == 0, "无法创建测试 PKG")
    if case .identified(let packageIdentity) = SystemInstallerInspector().inspect(package) {
        try require(packageIdentity.bundleIdentifier == "org.example.InstallerFixture", "PKG 应用标识解析错误")
    } else {
        throw SelfTestError.failed("PKG 应用标识读取失败")
    }

    print("MacSpaceGuard self-test passed")
} catch {
    fputs("MacSpaceGuard self-test failed: \(error)\n", stderr)
    exit(1)
}

private struct TestInstallerInspector: InstallerIdentityInspecting {
    func inspect(_ installer: URL) -> InstallerInspection {
        if installer.lastPathComponent == "Google-Chrome-130.0-arm64.dmg" {
            return .identified(InstallerIdentity(name: "Google Chrome", bundleIdentifier: "com.google.Chrome", version: "130.0"))
        }
        if installer.lastPathComponent == "Figma.dmg" {
            return .identified(InstallerIdentity(name: "Figma", bundleIdentifier: "com.figma.Desktop.dua", version: "1.0", isBootstrapper: true))
        }
        if installer.lastPathComponent == "OmniGrafflepjb_jb51.dmg" {
            return .identified(InstallerIdentity(name: "CORE Keygen", bundleIdentifier: "com.core.kg", version: nil))
        }
        return .unknown("测试安装包无内容")
    }
}
