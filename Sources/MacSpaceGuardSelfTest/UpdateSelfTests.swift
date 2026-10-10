import Foundation
import MacSpaceGuardCore

/// Runs without Xcode/XCTest, always using fake release responses and isolated preferences.
func runUpdateSelfTests() async throws {
    let versions = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.10", "1.0.0-rc.1", "1.0.0", "1.0.1", "2.0.0"]
    for (a, b) in zip(versions, versions.dropFirst()) {
        try require(ReleaseVersion(a)! < ReleaseVersion(b)!, "版本先后顺序错误：\(a) / \(b)")
    }
    try require(ReleaseVersion("v1.0.0+one") == ReleaseVersion("1.0.0+two"), "构建后缀错误地影响更新优先级")
    for invalid in ["1.0", "01.0.0", "1.0.0-", "1.0.0-beta.02", "1.0.0+", "1.0.0-测试"] {
        try require(ReleaseVersion(invalid) == nil, "异常版本号没有拒绝：\(invalid)")
    }
    var fixtures = [updateFixture("1.1.0-beta.1", beta: true), updateFixture("1.0.1"), updateFixture("1.0.0-beta.10", beta: true)]
    let data = try JSONSerialization.data(withJSONObject: fixtures)
    let decoded = try JSONDecoder().decode([GitHubRelease].self, from: data)
    let stable = try UpdateChecker.selectUpdate(from: decoded, currentVersion: "1.0.0-beta.2", channel: .stable)
    try require(stable?.version == "1.0.1", "正式版频道混入测试版")
    let beta = try UpdateChecker.selectUpdate(from: decoded, currentVersion: "1.0.0-beta.2", channel: .includingPrereleases)
    try require(beta?.version == "1.1.0-beta.1" && beta?.isPrerelease == true, "测试版频道或排序错误")
    let noDowngrade = try UpdateChecker.selectUpdate(from: decoded, currentVersion: "2.0.0", channel: .includingPrereleases)
    try require(noDowngrade == nil, "提示了同版本或旧版本")
    var draft = updateFixture("9.0.0"); draft["draft"] = true
    var unpublished = updateFixture("8.0.0"); unpublished["published_at"] = NSNull()
    var noDMG = updateFixture("7.0.0"); noDMG["assets"] = []
    var externalURL = updateFixture("6.0.0"); externalURL["html_url"] = "https://evil.example/test"
    var externalAsset = updateFixture("5.0.0")
    externalAsset["assets"] = [["name": "MSG-5.0.0-AppleSilicon.dmg", "state": "uploaded", "size": 1,
                                 "browser_download_url": "https://evil.example/app.dmg"]]
    var pendingAsset = updateFixture("4.0.0")
    pendingAsset["assets"] = [["name": "MSG-4.0.0-AppleSilicon.dmg", "state": "new", "size": 1,
        "browser_download_url": "https://github.com/Dimoo-rich/MacSpaceGuard/releases/download/v4.0.0/MSG-4.0.0-AppleSilicon.dmg"]]
    fixtures = [draft, unpublished, noDMG, externalURL, externalAsset, pendingAsset, updateFixture("1.0.0-beta.3", beta: true)]
    let filtered = try JSONDecoder().decode([GitHubRelease].self, from: JSONSerialization.data(withJSONObject: fixtures))
    let safeUpdate = try UpdateChecker.selectUpdate(from: filtered, currentVersion: "1.0.0-beta.2", channel: .includingPrereleases)
    try require(safeUpdate?.version == "1.0.0-beta.3", "草稿、缺少 DMG 或非官方地址未被过滤")

    let suite = "MSGUpdateSelfTest-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else { throw SelfTestError.failed("无法创建隔离偏好设置") }
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = UpdatePreferences(defaults: defaults, installedVersion: "1.0.0-beta.2")
    let now = Date(timeIntervalSince1970: 1_000_000)
    try require(!settings.dailyChecksEnabled && !settings.isDailyCheckDue(at: now), "每日更新检查不是默认关闭")
    try require(settings.channel == .includingPrereleases, "测试版默认频道错误")
    settings.dailyChecksEnabled = true
    try require(settings.isDailyCheckDue(at: now), "启用首次检查失败")
    settings.lastAttempt = now
    try require(!settings.isDailyCheckDue(at: now.addingTimeInterval(86_399)), "每天多次自动请求")
    try require(settings.isDailyCheckDue(at: now.addingTimeInterval(86_400)), "每日检查未到期")
    try require(settings.isDailyCheckDue(at: now.addingTimeInterval(-1)), "时间回退导致永久不检查")
    settings.channel = .stable
    settings.lastNotifiedVersion = "1.0.1"
    let reloaded = UpdatePreferences(defaults: defaults, installedVersion: "1.0.0-beta.2")
    try require(reloaded.channel == .stable && reloaded.lastNotifiedVersion == "1.0.1", "频道和提醒去重未持久化")
    settings.dailyChecksEnabled = false
    try require(!settings.isDailyCheckDue(at: now.addingTimeInterval(100_000)), "关闭后仍会自动请求")

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [UpdateMockProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel(); UpdateMockProtocol.handler = nil }
    let checker = UpdateChecker(session: session)
    var requests = 0
    UpdateMockProtocol.handler = { request in
        try require(request.httpMethod == "GET" && request.httpBody == nil, "更新检查发送了非只读请求")
        try require(request.url?.host == "api.github.com", "查询连接了非官方服务")
        try require(request.value(forHTTPHeaderField: "Authorization") == nil, "公开查询携带了账号凭据")
        requests += 1
        return (200, data)
    }
    let networkResult = try await checker.check(currentVersion: "1.0.0-beta.2", channel: .stable)
    try require(networkResult?.version == "1.0.1" && requests == 1, "模拟网络成功响应解析失败")
    // Pagination uses fixed official URLs instead of arbitrary Link-header targets.
    UpdateMockProtocol.handler = { request in
        requests += 1
        if request.url?.query?.contains("page=2") == true { return (200, data) }
        return (200, try JSONSerialization.data(withJSONObject: Array(repeating: updateFixture("0.1.0"), count: 100)))
    }
    requests = 0
    let paged = try await checker.check(currentVersion: "1.0.0-beta.2", channel: .stable)
    try require(paged?.version == "1.0.1" && requests == 2, "分页未读到新版")
    for status in [403, 404, 429, 500, 302] {
        UpdateMockProtocol.handler = { _ in (status, Data("{}".utf8)) }
        do {
            _ = try await checker.check(currentVersion: "1.0.0-beta.2", channel: .stable)
            throw SelfTestError.failed("HTTP 错误被当成已是最新版：\(status)")
        } catch UpdateCheckError.httpStatus(let received) {
            try require(received == status, "HTTP 状态码错误")
        }
    }
    UpdateMockProtocol.handler = { _ in (200, Data("not-json".utf8)) }
    do {
        _ = try await checker.check(currentVersion: "1.0.0-beta.2", channel: .stable)
        throw SelfTestError.failed("异常 JSON 被当成已是最新版")
    } catch UpdateCheckError.invalidResponse {}
    UpdateMockProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
    do {
        _ = try await checker.check(currentVersion: "1.0.0-beta.2", channel: .stable)
        throw SelfTestError.failed("断网被当成已是最新版")
    } catch let error as URLError { try require(error.code == .notConnectedToInternet, "断网错误丢失") }
    UpdateMockProtocol.handler = { _ in throw URLError(.timedOut) }
    do {
        _ = try await checker.check(currentVersion: "1.0.0-beta.2", channel: .stable)
        throw SelfTestError.failed("超时被当成已是最新版")
    } catch let error as URLError { try require(error.code == .timedOut, "超时错误丢失") }
    print("Update self-test passed: version ordering, release channels, URL/DMG filtering, consent/cadence, persistence, pagination, HTTP, malformed data, offline and timeout")
}

private func updateFixture(_ version: String, beta: Bool = false) -> [String: Any] {
    let tag = "v" + version
    let name = "MSG-\(version)-AppleSilicon.dmg"
    return ["tag_name": tag, "name": "MSG " + version, "body": "更新功能模拟说明",
            "html_url": "https://github.com/Dimoo-rich/MacSpaceGuard/releases/tag/\(tag)",
            "draft": false, "prerelease": beta, "published_at": "2026-10-10T00:00:00Z",
            "assets": [["name": name, "state": "uploaded", "size": 1,
                        "browser_download_url": "https://github.com/Dimoo-rich/MacSpaceGuard/releases/download/\(tag)/\(name)"]]]
}

private final class UpdateMockProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler, let url = request.url else { throw URLError(.badURL) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
