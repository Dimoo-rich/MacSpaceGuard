import Foundation

/// SemVer precedence, including numeric beta identifiers; build metadata is ignored.
public struct ReleaseVersion: Comparable, Sendable {
    public let major: UInt64
    public let minor: UInt64
    public let patch: UInt64
    public let prerelease: [String]

    public init?(_ input: String) {
        guard input.count <= 128 else { return nil }
        let text = input.hasPrefix("v") ? String(input.dropFirst()) : input
        let build = text.split(separator: "+", omittingEmptySubsequences: false)
        guard build.count <= 2, !build[0].isEmpty else { return nil }
        if build.count == 2 {
            guard Self.identifiers(String(build[1]), numericLeadingZeroAllowed: true) != nil else { return nil }
        }
        let sections = build[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = sections[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3 else { return nil }
        let parsed = numbers.compactMap { part -> UInt64? in
            guard Self.isNumeric(String(part)), part.count == 1 || part.first != "0" else { return nil }
            return UInt64(part)
        }
        guard parsed.count == 3 else { return nil }
        var identifiers: [String] = []
        if sections.count == 2 {
            guard let values = Self.identifiers(String(sections[1]), numericLeadingZeroAllowed: false) else { return nil }
            identifiers = values
        }
        major = parsed[0]; minor = parsed[1]; patch = parsed[2]; prerelease = identifiers
    }

    private static func isNumeric(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { (48...57).contains($0) }
    }

    private static func identifiers(_ text: String, numericLeadingZeroAllowed: Bool) -> [String]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.allSatisfy({ part in
            !part.isEmpty && part.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
            } && (numericLeadingZeroAllowed || !isNumeric(part) || part.count == 1 || part.first != "0")
        }) else { return nil }
        return parts
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            let leftNumeric = isNumeric(left), rightNumeric = isNumeric(right)
            if leftNumeric && rightNumeric {
                return left.count == right.count ? left < right : left.count < right.count
            }
            if leftNumeric != rightNumeric { return leftNumeric }
            return left < right
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}

public enum UpdateChannel: String, CaseIterable, Sendable {
    case stable
    case includingPrereleases

    public var displayName: String {
        self == .stable ? "仅正式版" : "正式版及测试版"
    }
}

public struct GitHubRelease: Decodable {
    public struct Asset: Decodable {
        public let name: String
        public let state: String
        public let size: Int64
        public let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name, state, size
            case browserDownloadURL = "browser_download_url"
        }
    }

    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: String
    public let draft: Bool
    public let prerelease: Bool
    public let publishedAt: String?
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case name, body, draft, prerelease, assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }
}

public struct AvailableUpdate: Sendable {
    public let version: String
    public let isPrerelease: Bool
    public let notes: String
    public let releaseURL: URL
}

public enum UpdateCheckError: LocalizedError {
    case invalidCurrentVersion
    case invalidResponse
    case httpStatus(Int)
    case tooMuchData
    case tooManyPages

    public var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion: return "无法识别当前应用版本，请到官方发布页核对。"
        case .invalidResponse: return "版本服务返回的数据无法识别，请稍后重试。"
        case .httpStatus(403): return "版本服务暂时拒绝了查询，可能存在访问或请求限制，请稍后重试。"
        case .httpStatus(429):
            return "版本服务暂时限制了请求次数，请稍后重试。"
        case .httpStatus(let code): return "无法获取版本信息（服务响应 \(code)），请稍后重试。"
        case .tooMuchData, .tooManyPages: return "版本信息超出查询范围，请到官方发布页查看。"
        }
    }
}

/// Only reads public release metadata. Never downloads, installs or executes an update.
public final class UpdateChecker {
    public static let releasesURL = URL(string: "https://github.com/Dimoo-rich/MacSpaceGuard/releases")!
    private let session: URLSession
    private static let repositoryPath = "/Dimoo-rich/MacSpaceGuard"

    public init(session: URLSession? = nil) {
        if let session { self.session = session; return }
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config, delegate: ReleaseSessionDelegate(), delegateQueue: nil)
    }

    public func check(currentVersion: String, channel: UpdateChannel) async throws -> AvailableUpdate? {
        var releases: [GitHubRelease] = []
        // Read fixed same-origin pages, never URLs supplied in response headers.
        for page in 1...10 {
            try Task.checkCancellation()
            let url = URL(string: "https://api.github.com/repos/Dimoo-rich/MacSpaceGuard/releases?per_page=100&page=\(page)")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.setValue("MacSpaceGuard-UpdateCheck", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.url == url else { throw UpdateCheckError.invalidResponse }
            guard http.statusCode == 200 else { throw UpdateCheckError.httpStatus(http.statusCode) }
            guard data.count <= 2_000_000 else { throw UpdateCheckError.tooMuchData }
            guard let batch = try? JSONDecoder().decode([GitHubRelease].self, from: data), batch.count <= 100 else {
                throw UpdateCheckError.invalidResponse
            }
            releases += batch
            if batch.count < 100 {
                return try Self.selectUpdate(from: releases, currentVersion: currentVersion, channel: channel)
            }
        }
        throw UpdateCheckError.tooManyPages
    }

    public static func selectUpdate(from releases: [GitHubRelease], currentVersion: String,
                                    channel: UpdateChannel) throws -> AvailableUpdate? {
        guard let current = ReleaseVersion(currentVersion) else { throw UpdateCheckError.invalidCurrentVersion }
        let candidates = releases.compactMap { release -> (ReleaseVersion, AvailableUpdate)? in
            guard !release.draft, release.publishedAt != nil,
                  let version = ReleaseVersion(release.tagName), version > current else { return nil }
            let isBeta = release.prerelease || !version.prerelease.isEmpty
            guard channel != .stable || !isBeta else { return nil }
            let releasePath = repositoryPath + "/releases/tag/" + release.tagName
            guard let url = validatedGitHubURL(release.htmlURL, exactPath: releasePath) else { return nil }
            let displayVersion = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            let expectedName = "MSG-\(displayVersion)-AppleSilicon.dmg"
            let downloadPath = repositoryPath + "/releases/download/" + release.tagName + "/" + expectedName
            guard release.assets.contains(where: {
                $0.name == expectedName && $0.state == "uploaded" && $0.size > 0 &&
                validatedGitHubURL($0.browserDownloadURL, exactPath: downloadPath) != nil
            }) else { return nil }
            return (version, AvailableUpdate(version: displayVersion, isPrerelease: isBeta,
                notes: String((release.body ?? "发布者没有提供更新说明，请到发布页查看。").prefix(5_000)), releaseURL: url))
        }
        return candidates.max(by: { $0.0 < $1.0 })?.1
    }

    private static func validatedGitHubURL(_ text: String, exactPath: String) -> URL? {
        guard let parts = URLComponents(string: text), parts.scheme == "https", parts.host == "github.com",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil, parts.path == exactPath else { return nil }
        return parts.url
    }
}

private final class ReleaseSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Local-only preferences. A fresh install never starts a network request by itself.
public final class UpdatePreferences {
    private let defaults: UserDefaults
    private let installedVersion: String
    private let prefix = "MSGUpdates."

    public init(defaults: UserDefaults = .standard, installedVersion: String = ReleasePolicy.version) {
        self.defaults = defaults; self.installedVersion = installedVersion
    }

    public var dailyChecksEnabled: Bool {
        get { defaults.bool(forKey: prefix + "dailyEnabled") }
        set { defaults.set(newValue, forKey: prefix + "dailyEnabled") }
    }
    public var channel: UpdateChannel {
        get {
            if let saved = defaults.string(forKey: prefix + "channel"), let channel = UpdateChannel(rawValue: saved) { return channel }
            return ReleaseVersion(installedVersion)?.prerelease.isEmpty == false ? .includingPrereleases : .stable
        }
        set { defaults.set(newValue.rawValue, forKey: prefix + "channel") }
    }
    public var lastAttempt: Date? {
        get { defaults.object(forKey: prefix + "lastAttempt") as? Date }
        set { defaults.set(newValue, forKey: prefix + "lastAttempt") }
    }
    public var lastNotifiedVersion: String? {
        get { defaults.string(forKey: prefix + "lastNotified") }
        set { defaults.set(newValue, forKey: prefix + "lastNotified") }
    }
    public func isDailyCheckDue(at date: Date = Date()) -> Bool {
        guard dailyChecksEnabled else { return false }
        guard let lastAttempt else { return true }
        return date < lastAttempt || date.timeIntervalSince(lastAttempt) >= 86_400
    }
}
