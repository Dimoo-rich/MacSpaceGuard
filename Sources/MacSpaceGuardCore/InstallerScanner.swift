import AppKit
import Foundation

public struct InstalledApplication: Sendable {
    public let name: String
    public let version: String?
    public let url: URL
    public let bundleIdentifier: String?

    public init(name: String, version: String?, url: URL, bundleIdentifier: String? = nil) {
        self.name = name
        self.version = version
        self.url = url
        self.bundleIdentifier = bundleIdentifier
    }

    public var isInApplicationsDirectory: Bool {
        let path = url.standardizedFileURL.path
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true).path
        return path.hasPrefix("/Applications/") ||
            path.hasPrefix("/System/Applications/") ||
            path.hasPrefix(homeApplications + "/")
    }
}

public struct InstallerIdentity: Sendable {
    public let name: String
    public let bundleIdentifier: String
    public let version: String?
    public let isBootstrapper: Bool

    public init(name: String, bundleIdentifier: String, version: String?, isBootstrapper: Bool = false) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.isBootstrapper = isBootstrapper
    }
}

public enum InstallerInspection: Sendable {
    case identified(InstallerIdentity)
    case unknown(String)
}

public protocol InstallerIdentityInspecting {
    func inspect(_ installer: URL) -> InstallerInspection
}

public enum InstallerEvidence: Sendable {
    case installed(InstallerIdentity, InstalledApplication)
    case notFound(InstallerIdentity)
    case bootstrapper(InstallerIdentity, InstalledApplication?)
    case unexpectedContents(InstallerIdentity, InstalledApplication?)
    case cannotIdentify(String)

    public var containedAppName: String {
        switch self {
        case .installed(let identity, _), .notFound(let identity),
             .bootstrapper(let identity, _), .unexpectedContents(let identity, _):
            return identity.name
        case .cannotIdentify: return "无法识别"
        }
    }

    public var title: String {
        switch self {
        case .installed(let identity, let app):
            if !app.isInApplicationsDirectory { return "找到应用（其他位置）" }
            if let packaged = identity.version, let installed = app.version, packaged != installed {
                return "已安装（版本不同）"
            }
            return "已安装对应应用"
        case .notFound: return "未找到对应应用"
        case .bootstrapper(let identity, let app):
            return app.map { "已找到 \($0.name)；此包是引导器" } ?? "\(identity.name) 引导器；未找到主应用"
        case .unexpectedContents(_, let app):
            return app.map { "包内并非 \($0.name)" } ?? "包内应用与文件名不符"
        case .cannotIdentify: return "无法确认"
        }
    }

    public var explanation: String {
        switch self {
        case .installed(let identity, let app):
            let packageVersion = identity.version ?? "未知"
            let installedVersion = app.version ?? "未知"
            return "安装包内是 \(identity.name)（\(identity.bundleIdentifier)，版本 \(packageVersion)）；本机找到 \(app.name)（版本 \(installedVersion)），位置：\(app.url.path)。仅核对标识，不验证安装包来源或证明当前应用来自此包。"
        case .notFound(let identity):
            return "安装包内是 \(identity.name)（\(identity.bundleIdentifier)）；在常见应用目录及系统应用登记中未找到对应应用。可能安装在其他位置，不能断言从未安装。"
        case .bootstrapper(let identity, let app):
            let installed = app.map { "电脑上已找到主应用 \($0.name)，位置：\($0.url.path)。" } ?? "电脑上未找到对应主应用。"
            return "这个下载文件里是 \(identity.name) 的安装引导器，不是完整的主应用。\(installed)只能确认电脑上是否有主应用，不能证明它是通过这个文件安装的。移到废纸篓只会删除此下载文件，不会卸载应用。"
        case .unexpectedContents(let identity, let app):
            let mentioned = app.map { "文件名看起来像 \($0.name) 的安装包，但" } ?? "文件名与实际内容不符："
            return "\(mentioned)包内识别到的是 \(identity.name)（\(identity.bundleIdentifier)）。不能把它当作文件名所示应用的安装包，也不要运行来源未核实的包内程序。如果不需要这个下载文件，可以选择移到废纸篓；不会卸载应用。"
        case .cannotIdentify(let reason):
            return "无法读取安装包内的唯一应用标识：\(reason)。不能判断对应应用是否已安装。"
        }
    }
}

public struct InstallerFinding: Sendable {
    public let url: URL
    public let bytes: Int64
    public let modificationDate: Date
    public let fileIdentity: FileIdentity
    public let evidence: InstallerEvidence

    public init(url: URL, bytes: Int64, modificationDate: Date, fileIdentity: FileIdentity, evidence: InstallerEvidence) {
        self.url = url
        self.bytes = bytes
        self.modificationDate = modificationDate
        self.fileIdentity = fileIdentity
        self.evidence = evidence
    }
}

public struct InstallerScanner {
    private let fileManager: FileManager
    private let inspector: any InstallerIdentityInspecting
    public static let supportedExtensions: Set<String> = ["dmg", "pkg"]

    public init(fileManager: FileManager = .default, inspector: any InstallerIdentityInspecting = SystemInstallerInspector()) {
        self.fileManager = fileManager
        self.inspector = inspector
    }

    public func scan(directory: URL, installedApplications: [InstalledApplication]? = nil) throws -> [InstallerFinding] {
        let directory = directory.standardizedFileURL.resolvingSymlinksInPath()
        let applications = installedApplications ?? findInstalledApplications()
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return files.compactMap { file -> InstallerFinding? in
            guard Self.supportedExtensions.contains(file.pathExtension.lowercased()),
                  let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let fileIdentity = FileIdentity(url: file),
                  let modified = values.contentModificationDate else { return nil }

            let evidence: InstallerEvidence
            switch inspector.inspect(file) {
            case .unknown(let reason):
                evidence = .cannotIdentify(reason)
            case .identified(let identity):
                let matches = applications.filter { $0.bundleIdentifier == identity.bundleIdentifier }
                if identity.isBootstrapper {
                    let targetID = String(identity.bundleIdentifier.dropLast(4))
                    let app = applications.first { $0.bundleIdentifier == targetID }
                        ?? (installedApplications == nil ? registeredApplication(for: targetID) : nil)
                    evidence = .bootstrapper(identity, app)
                } else if file.pathExtension.lowercased() == "dmg",
                          !Self.name(identity.name, isRelatedTo: file.deletingPathExtension().lastPathComponent) {
                    let candidates = applications.filter {
                        let name = Self.normalizedName($0.name)
                        return name.count >= 5 && Self.normalizedName(file.deletingPathExtension().lastPathComponent).hasPrefix(name)
                    }
                    evidence = .unexpectedContents(identity, candidates.count == 1 ? candidates[0] : nil)
                } else if let app = matches.first ?? (installedApplications == nil ? registeredApplication(for: identity.bundleIdentifier) : nil) {
                    evidence = .installed(identity, app)
                } else {
                    evidence = .notFound(identity)
                }
            }
            return InstallerFinding(url: file, bytes: Int64(values.fileSize ?? 0), modificationDate: modified, fileIdentity: fileIdentity, evidence: evidence)
        }.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    public func findInstalledApplications(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [InstalledApplication] {
        let directories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
        return directories.flatMap { directory -> [InstalledApplication] in
            guard let entries = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
            return entries.filter { $0.pathExtension.lowercased() == "app" }.compactMap(Self.application(at:))
        }
    }

    private func registeredApplication(for identifier: String) -> InstalledApplication? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
              fileManager.fileExists(atPath: url.path),
              let app = Self.application(at: url),
              app.bundleIdentifier == identifier else { return nil }
        return app
    }

    private static func application(at url: URL) -> InstalledApplication? {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return InstalledApplication(name: name, version: version, url: url, bundleIdentifier: identifier)
    }

    private static func name(_ contentName: String, isRelatedTo fileName: String) -> Bool {
        let content = normalizedName(contentName)
        let file = normalizedName(fileName)
        return content.count < 5 || file.contains(content)
    }

    private static func normalizedName(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }
}

/// Reads metadata only. Images are mounted read-only without opening Finder;
/// packages are expanded into a temporary directory without running scripts.
public struct SystemInstallerInspector: InstallerIdentityInspecting {
    private let fileManager = FileManager.default

    public init() {}

    public func inspect(_ installer: URL) -> InstallerInspection {
        switch installer.pathExtension.lowercased() {
        case "dmg": return inspectDiskImage(installer)
        case "pkg": return inspectPackage(installer)
        default: return .unknown("不支持的安装包格式")
        }
    }

    private func inspectDiskImage(_ installer: URL) -> InstallerInspection {
        let root = fileManager.temporaryDirectory.appendingPathComponent("MSG-dmg-\(UUID().uuidString)", isDirectory: true)
        do { try fileManager.createDirectory(at: root, withIntermediateDirectories: true) }
        catch { return .unknown("无法创建临时检查目录") }
        // Never recursively remove a root that might still contain a mounted volume.
        defer {
            if let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil), entries.isEmpty {
                try? fileManager.removeItem(at: root)
            }
        }

        let output = run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-noautoopen", "-plist", "-mountroot", root.path, installer.path], timeout: 30)
        guard output.succeeded,
              let plist = try? PropertyListSerialization.propertyList(from: output.data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            detachMountedVolumes(in: root)
            return .unknown("磁盘映像无法安全地只读挂载")
        }
        let mounts = entities.compactMap { $0["mount-point"] as? String }
            .map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
            .filter { $0.deletingLastPathComponent() == root.standardizedFileURL }
        defer { for mount in mounts.reversed() { _ = run("/usr/bin/hdiutil", ["detach", mount.path], timeout: 15) } }
        guard !mounts.isEmpty else { return .unknown("磁盘映像没有可读取的卷") }
        var identities: [InstallerIdentity] = []
        for mount in mounts {
            for app in containedItems(in: mount, extensions: ["app"], depth: 2) {
                if let identity = appIdentity(at: app) { identities.append(identity) }
            }
            for package in containedItems(in: mount, extensions: ["pkg"], depth: 2) {
                if case .identified(let identity) = inspectPackage(package) { identities.append(identity) }
            }
        }
        return uniqueIdentity(from: identities)
    }

    private func inspectPackage(_ installer: URL) -> InstallerInspection {
        let root = fileManager.temporaryDirectory.appendingPathComponent("MSG-pkg-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let output = run("/usr/sbin/pkgutil", ["--expand", installer.path, root.path], timeout: 30)
        guard output.succeeded else { return .unknown("无法读取 PKG 元数据") }
        var identities: [InstallerIdentity] = []
        for info in containedItems(in: root, named: "PackageInfo", depth: 3) {
            guard let parser = XMLParser(contentsOf: info) else { continue }
            let delegate = PackageBundleParser()
            parser.delegate = delegate
            if parser.parse() { identities.append(contentsOf: delegate.identities) }
        }
        return uniqueIdentity(from: identities)
    }

    private func appIdentity(at url: URL) -> InstallerIdentity? {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return nil }
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let name = url.deletingPathExtension().lastPathComponent
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let isBootstrapper = bundleName == "DynamicUniversalApp" && identifier.hasSuffix(".dua")
        return InstallerIdentity(name: name, bundleIdentifier: identifier, version: version, isBootstrapper: isBootstrapper)
    }

    private func uniqueIdentity(from identities: [InstallerIdentity]) -> InstallerInspection {
        let byID = Dictionary(grouping: identities, by: \.bundleIdentifier)
        guard byID.count == 1, let identity = byID.values.first?.first else {
            return .unknown(identities.isEmpty ? "未找到可识别的应用" : "安装包包含多个应用，无法确定主应用")
        }
        return .identified(identity)
    }

    private func containedItems(in root: URL, extensions: Set<String> = [], named: String? = nil, depth: Int) -> [URL] {
        guard depth >= 0, let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return [] }
        var results: [URL] = []
        for entry in entries.prefix(300) {
            guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]), values.isSymbolicLink != true else { continue }
            if extensions.contains(entry.pathExtension.lowercased()) || (named != nil && entry.lastPathComponent == named) {
                results.append(entry)
            } else if depth > 0 && values.isDirectory == true {
                results += containedItems(in: entry, extensions: extensions, named: named, depth: depth - 1)
            }
        }
        return results
    }

    private func detachMountedVolumes(in root: URL) {
        guard let mounts = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for mount in mounts where (try? mount.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            _ = run("/usr/bin/hdiutil", ["detach", mount.path], timeout: 15)
        }
    }

    private func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> (succeeded: Bool, data: Data) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (false, Data()) }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if process.isRunning { process.terminate(); process.waitUntilExit(); return (false, Data()) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus == 0, data)
    }
}

private final class PackageBundleParser: NSObject, XMLParserDelegate {
    var identities: [InstallerIdentity] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName == "bundle", let identifier = attributeDict["id"], !identifier.isEmpty else { return }
        let name = identifier.split(separator: ".").last.map(String.init) ?? identifier
        let version = attributeDict["CFBundleShortVersionString"] ?? attributeDict["CFBundleVersion"]
        identities.append(InstallerIdentity(name: name, bundleIdentifier: identifier, version: version))
    }
}
