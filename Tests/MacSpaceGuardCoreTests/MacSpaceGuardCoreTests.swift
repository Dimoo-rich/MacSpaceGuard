import XCTest
@testable import MacSpaceGuardCore

final class MacSpaceGuardCoreTests: XCTestCase {
    func testParsesSwapUsage() {
        let input = "total = 8192.00M  used = 3177.50M  free = 5014.50M"
        XCTAssertEqual(SystemMonitor.parseSwapUsage(input), 3_331_850_240)
    }

    func testParsesMemoryFreePercentage() {
        XCTAssertEqual(SystemMonitor.parseMemoryFreePercentage("System-wide memory free percentage: 30%"), 30)
    }

    func testScannerOnlyIncludesOldRegularFiles() throws {
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = temporary.appendingPathComponent("Library/Caches/TestCache", isDirectory: true)
        try fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporary) }

        let oldFile = cache.appendingPathComponent("old.bin")
        let recentFile = cache.appendingPathComponent("recent.bin")
        XCTAssertTrue(fileManager.createFile(atPath: oldFile.path, contents: Data(repeating: 1, count: 128)))
        XCTAssertTrue(fileManager.createFile(atPath: recentFile.path, contents: Data(repeating: 1, count: 256)))
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -20 * 86_400)], ofItemAtPath: oldFile.path)

        let rule = CacheRule(id: "test", displayName: "Test", relativePath: "Library/Caches/TestCache", minimumAgeDays: 7)
        let reports = CacheScanner().scan(rules: [rule], homeDirectory: temporary)

        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports[0].candidates.map(\.url.lastPathComponent), ["old.bin"])
        XCTAssertEqual(reports[0].reclaimableBytes, 128)
    }

    func testScannerRejectsSiblingPrefix() {
        let scanner = CacheScanner()
        let root = URL(fileURLWithPath: "/tmp/cache")
        let sibling = URL(fileURLWithPath: "/tmp/cache-evil/file")
        XCTAssertFalse(scanner.isSafeDescendant(sibling, of: root))
    }

    func testCustomCutoffAndRunningAppProtection() throws {
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = temporary.appendingPathComponent("Library/Caches/TestCache", isDirectory: true)
        try fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporary) }
        let fakeTrash = temporary.appendingPathComponent("FakeTrash", isDirectory: true)
        try fileManager.createDirectory(at: fakeTrash, withIntermediateDirectories: true)
        let cleaner = CleanupService(fileManager: fileManager, trashItem: { source in
            try fileManager.moveItem(at: source, to: fakeTrash.appendingPathComponent(source.lastPathComponent))
        })
        let file = cache.appendingPathComponent("old.bin")
        XCTAssertTrue(fileManager.createFile(atPath: file.path, contents: Data(repeating: 1, count: 32)))
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -20 * 86_400)], ofItemAtPath: file.path)

        let rule = CacheRule(id: "test", displayName: "Test", relativePath: "Library/Caches/TestCache", minimumAgeDays: 7, relatedBundleIdentifiers: ["com.example.running"])
        let scanner = CacheScanner()
        XCTAssertTrue(scanner.scan(rules: [rule], homeDirectory: temporary, cutoffDate: Date(timeIntervalSinceNow: -25 * 86_400))[0].candidates.isEmpty)
        let reports = scanner.scan(rules: [rule], homeDirectory: temporary, cutoffDate: Date(timeIntervalSinceNow: -10 * 86_400))
        XCTAssertEqual(reports[0].candidates.count, 1)

        let blocked = cleaner.moveToTrash(reports: reports, homeDirectory: temporary, runningBundleIdentifiers: ["com.example.running"])
        XCTAssertEqual(blocked.movedFiles, 0)
        XCTAssertTrue(fileManager.fileExists(atPath: file.path))

        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        let changed = cleaner.moveToTrash(reports: reports, homeDirectory: temporary)
        XCTAssertEqual(changed.movedFiles, 0)
        XCTAssertTrue(fileManager.fileExists(atPath: file.path))

        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -20 * 86_400)], ofItemAtPath: file.path)
        let refreshed = scanner.scan(rules: [rule], homeDirectory: temporary)
        let wrongRule = cleaner.moveToTrash(
            reports: refreshed,
            homeDirectory: temporary,
            runningBundleIdentifiers: ["com.example.running"],
            confirmedRunningRuleIDs: ["other-rule"]
        )
        XCTAssertEqual(wrongRule.movedFiles, 0)
        XCTAssertTrue(fileManager.fileExists(atPath: file.path))

        let forced = cleaner.moveToTrash(
            reports: refreshed,
            homeDirectory: temporary,
            runningBundleIdentifiers: ["com.example.running"],
            confirmedRunningRuleIDs: [rule.id]
        )
        XCTAssertEqual(forced.movedFiles, 1)
        XCTAssertFalse(fileManager.fileExists(atPath: file.path))
        XCTAssertTrue(fileManager.fileExists(atPath: fakeTrash.appendingPathComponent(file.lastPathComponent).path))
    }

    func testLogsAreHardBlockedAndRunningRulesBecomeHighRisk() {
        let scanner = CacheScanner()
        let logs = CacheRule(id: "logs", displayName: "Logs", relativePath: "Library/Logs", minimumAgeDays: 30)
        XCTAssertNil(scanner.safeRoot(for: logs))
        XCTAssertFalse(CacheScanner.defaultRules.contains { $0.relativePath == "Library/Logs" })

        let chrome = CacheScanner.defaultRules.first { $0.id == "chrome-web-cache" }!
        XCTAssertEqual(chrome.effectiveRisk(whileRunning: []), .caution)
        XCTAssertEqual(chrome.effectiveRisk(whileRunning: ["com.google.Chrome"]), .high)
    }

    func testInstallerScannerMatchesBundleIdentifierNotFilename() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("MSG-installers-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }

        let matching = directory.appendingPathComponent("OmniGrafflepjb_jb51.dmg")
        let unmatched = directory.appendingPathComponent("Other.pkg")
        let ignored = directory.appendingPathComponent("photos.zip")
        XCTAssertTrue(manager.createFile(atPath: matching.path, contents: Data([1, 2])))
        XCTAssertTrue(manager.createFile(atPath: unmatched.path, contents: Data([3])))
        XCTAssertTrue(manager.createFile(atPath: ignored.path, contents: Data([4])))
        let installed = InstalledApplication(name: "OmniGraffle", version: "7.25", url: URL(fileURLWithPath: "/Applications/OmniGraffle.app"), bundleIdentifier: "com.omnigroup.OmniGraffle7")
        let inspector = StubInstallerInspector(results: [
            matching.lastPathComponent: .identified(InstallerIdentity(name: "OmniGraffle", bundleIdentifier: "com.omnigroup.OmniGraffle7", version: "7.24")),
            unmatched.lastPathComponent: .unknown("测试中无法读取")
        ])
        let results = try InstallerScanner(inspector: inspector).scan(directory: directory, installedApplications: [installed])

        XCTAssertEqual(results.count, 2)
        guard let omni = results.first(where: { $0.url.lastPathComponent == matching.lastPathComponent }),
              let other = results.first(where: { $0.url.lastPathComponent == unmatched.lastPathComponent }) else {
            XCTFail("Missing installer results")
            return
        }
        if case .installed(let identity, let application) = omni.evidence {
            XCTAssertEqual(identity.bundleIdentifier, "com.omnigroup.OmniGraffle7")
            XCTAssertEqual(application.version, "7.25")
            XCTAssertEqual(omni.evidence.title, "已安装（版本不同）")
        } else {
            XCTFail("Expected installed-app evidence")
        }
        if case .cannotIdentify = other.evidence {
            XCTAssertEqual(other.evidence.title, "无法确认")
        } else {
            XCTFail("Expected unknown evidence")
        }
    }

    func testInstallerScannerReportsNotFoundOnlyWithIdentifiedBundle() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("MSG-installers-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        let package = directory.appendingPathComponent("anything.pkg")
        XCTAssertTrue(manager.createFile(atPath: package.path, contents: Data([1])))
        let inspector = StubInstallerInspector(results: [
            package.lastPathComponent: .identified(InstallerIdentity(name: "Example", bundleIdentifier: "org.example.app", version: nil))
        ])
        let finding = try XCTUnwrap(InstallerScanner(inspector: inspector).scan(directory: directory, installedApplications: []).first)
        if case .notFound(let identity) = finding.evidence {
            XCTAssertEqual(identity.bundleIdentifier, "org.example.app")
            XCTAssertTrue(finding.evidence.explanation.contains("不能断言"))
        } else {
            XCTFail("Expected not-found evidence")
        }
    }

    func testInstallerScannerSeparatesBootstrapperAndMisnamedContents() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("MSG-installers-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        let figma = directory.appendingPathComponent("Figma.dmg")
        let omni = directory.appendingPathComponent("OmniGrafflepjb_jb51.dmg")
        XCTAssertTrue(manager.createFile(atPath: figma.path, contents: Data([1])))
        XCTAssertTrue(manager.createFile(atPath: omni.path, contents: Data([2])))
        let inspector = StubInstallerInspector(results: [
            "Figma.dmg": .identified(InstallerIdentity(name: "Figma", bundleIdentifier: "com.figma.Desktop.dua", version: "1.0", isBootstrapper: true)),
            "OmniGrafflepjb_jb51.dmg": .identified(InstallerIdentity(name: "CORE Keygen", bundleIdentifier: "com.core.kg", version: nil))
        ])
        let installed = [
            InstalledApplication(name: "Figma", version: "116", url: URL(fileURLWithPath: "/Applications/Figma.app"), bundleIdentifier: "com.figma.Desktop"),
            InstalledApplication(name: "OmniGraffle", version: "7", url: URL(fileURLWithPath: "/Applications/OmniGraffle.app"), bundleIdentifier: "com.omnigroup.OmniGraffle7")
        ]
        let findings = try InstallerScanner(inspector: inspector).scan(directory: directory, installedApplications: installed)
        let figmaFinding = try XCTUnwrap(findings.first { $0.url.lastPathComponent == figma.lastPathComponent })
        let omniFinding = try XCTUnwrap(findings.first { $0.url.lastPathComponent == omni.lastPathComponent })
        if case .bootstrapper(_, let app) = figmaFinding.evidence {
            XCTAssertEqual(app?.name, "Figma")
            XCTAssertEqual(figmaFinding.evidence.title, "已找到 Figma；此包是引导器")
        } else { XCTFail("Expected bootstrapper") }
        if case .unexpectedContents(let identity, let mentionedApp) = omniFinding.evidence {
            XCTAssertEqual(identity.name, "CORE Keygen")
            XCTAssertEqual(mentionedApp?.name, "OmniGraffle")
            XCTAssertEqual(omniFinding.evidence.title, "包内并非 OmniGraffle")
        } else { XCTFail("Expected content mismatch") }
    }

    func testInstallerTrashRejectsFilesOutsideChosenFolder() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("MSG-selected-\(UUID().uuidString)", isDirectory: true)
        let elsewhere = manager.temporaryDirectory.appendingPathComponent("MSG-elsewhere-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        try manager.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        defer {
            try? manager.removeItem(at: directory)
            try? manager.removeItem(at: elsewhere)
        }
        let file = elsewhere.appendingPathComponent("not-selected.dmg")
        XCTAssertTrue(manager.createFile(atPath: file.path, contents: Data([1])))
        let modified = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
        let finding = InstallerFinding(url: file, bytes: 1, modificationDate: modified, fileIdentity: FileIdentity(url: file)!, evidence: .cannotIdentify("测试文件，不检查包内内容"))
        let result = InstallerTrashService().moveToTrash([finding], from: directory)
        XCTAssertEqual(result.movedFiles, 0)
        XCTAssertTrue(manager.fileExists(atPath: file.path))
    }

    func testCacheCleanupRejectsReplacementWithSameSizeAndDate() throws {
        let manager = FileManager.default
        let home = manager.temporaryDirectory.appendingPathComponent("MSG-identity-\(UUID().uuidString)", isDirectory: true)
        let root = home.appendingPathComponent("Library/Caches/TestCache", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: home) }
        let file = root.appendingPathComponent("old.bin")
        XCTAssertTrue(manager.createFile(atPath: file.path, contents: Data(repeating: 1, count: 16)))
        try manager.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -20 * 86_400)], ofItemAtPath: file.path)
        let rule = CacheRule(id: "test", displayName: "Test", relativePath: "Library/Caches/TestCache", minimumAgeDays: 7)
        let report = try XCTUnwrap(CacheScanner().scan(rules: [rule], homeDirectory: home).first)
        let candidate = try XCTUnwrap(report.candidates.first)
        try manager.moveItem(at: file, to: root.appendingPathComponent("original.bin"))
        XCTAssertTrue(manager.createFile(atPath: file.path, contents: Data(repeating: 2, count: 16)))
        try manager.setAttributes([.modificationDate: candidate.modificationDate], ofItemAtPath: file.path)

        let result = CleanupService(trashItem: { _ in XCTFail("不应移动替换后的文件") }).moveToTrash(reports: [report], homeDirectory: home)
        XCTAssertEqual(result.movedFiles, 0)
        XCTAssertTrue(manager.fileExists(atPath: file.path))
    }

    func testInstallerTrashRejectsReplacementWithSameSizeAndDate() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("MSG-installer-identity-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        let file = directory.appendingPathComponent("example.dmg")
        XCTAssertTrue(manager.createFile(atPath: file.path, contents: Data([1, 2])))
        let finding = try XCTUnwrap(InstallerScanner(inspector: StubInstallerInspector(results: [:])).scan(directory: directory, installedApplications: []).first)
        try manager.moveItem(at: file, to: directory.appendingPathComponent("original.dmg"))
        XCTAssertTrue(manager.createFile(atPath: file.path, contents: Data([3, 4])))
        try manager.setAttributes([.modificationDate: finding.modificationDate], ofItemAtPath: file.path)

        let result = InstallerTrashService().moveToTrash([finding], from: directory)
        XCTAssertEqual(result.movedFiles, 0)
        XCTAssertTrue(manager.fileExists(atPath: file.path))
    }
}

private struct StubInstallerInspector: InstallerIdentityInspecting {
    let results: [String: InstallerInspection]

    func inspect(_ installer: URL) -> InstallerInspection {
        results[installer.lastPathComponent] ?? .unknown("未提供测试结果")
    }
}
