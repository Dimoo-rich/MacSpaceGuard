import Foundation
import XCTest
@testable import MacSpaceGuardCore

final class UpdateCheckerTests: XCTestCase {
    func testSemanticVersionPrecedence() throws {
        let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta",
                       "1.0.0-beta.2", "1.0.0-beta.10", "1.0.0-rc.1", "1.0.0", "1.0.1", "1.1.0", "2.0.0"]
        let versions = try ordered.map { try XCTUnwrap(ReleaseVersion($0)) }
        for (a, b) in zip(versions, versions.dropFirst()) { XCTAssertLessThan(a, b) }
        XCTAssertEqual(ReleaseVersion("v1.0.0+build.1"), ReleaseVersion("1.0.0+build.2"))
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("1.0.0-beta.999999999999999999999")),
                          try XCTUnwrap(ReleaseVersion("1.0.0-beta.1000000000000000000000")))
    }

    func testRejectsMalformedVersions() {
        for value in ["", "1.0", "1.0.0.1", "v", "1.0.0-", "1.0.0-beta..2", "1.0.0-beta.02", "01.0.0",
                      "1.0.0+", "1.0.0+a+b", "1.0.0/bad", "1.0.0-测试", "18446744073709551616.0.0"] {
            XCTAssertNil(ReleaseVersion(value), value)
        }
    }

    func testChannelsSortVersionsInsteadOfReleaseOrder() throws {
        let releases = [fixture("1.0.0-beta.3", beta: true), fixture("1.0.1"), fixture("1.1.0-beta.1", beta: true), fixture("1.0.0")]
        XCTAssertEqual(try select(releases, channel: .stable)?.version, "1.0.1")
        XCTAssertEqual(try select(releases, channel: .includingPrereleases)?.version, "1.1.0-beta.1")
        XCTAssertNil(try select([fixture("1.0.0-beta.2", beta: true)], channel: .includingPrereleases))
        XCTAssertNil(try select([fixture("1.0.0", beta: true)], channel: .stable))
        XCTAssertNil(try select([fixture("1.0.1-beta.1")], channel: .stable))
    }

    func testOnlyPublishedReleasesWithCompleteMatchingDMGAreEligible() throws {
        let valid = fixture("1.0.0-beta.3", beta: true)
        let invalid = [fixture("9.0.0", draft: true), fixture("8.0.0", published: nil),
                       fixture("7.0.0", assetName: "Source code.zip"), fixture("6.0.0", assetState: "new"),
                       fixture("5.0.0", assetSize: 0), fixture("4.0.0", assetName: "MSG-4.0.0-Intel.dmg")]
        XCTAssertEqual(try select(invalid + [valid], channel: .includingPrereleases)?.version, valid.tagName.dropFirst().description)
    }

    func testOnlyExactOfficialHTTPSLinksCanBeOpened() throws {
        let badURLs = ["http://github.com/Dimoo-rich/MacSpaceGuard/releases/tag/v2.0.0",
                       "https://github.com.evil.test/Dimoo-rich/MacSpaceGuard/releases/tag/v2.0.0",
                       "https://github.com/other/repo/releases/tag/v2.0.0",
                       "https://github.com/Dimoo-rich/MacSpaceGuard/releases/tag/v2.0.0?redirect=evil",
                       "https://user@github.com/Dimoo-rich/MacSpaceGuard/releases/tag/v2.0.0",
                       "https://github.com:443/Dimoo-rich/MacSpaceGuard/releases/tag/v2.0.0",
                       "file:///Applications/MacSpaceGuard.app"]
        for url in badURLs {
            XCTAssertNil(try select([fixture("2.0.0", releaseURL: url)], channel: .includingPrereleases))
            XCTAssertNil(try select([fixture("2.0.0", downloadURL: url)], channel: .includingPrereleases))
        }
    }

    func testMissingNotesAndInvalidCurrentVersion() throws {
        let update = try select([fixture("2.0.0", body: nil)], channel: .stable)
        XCTAssertFalse(try XCTUnwrap(update).notes.isEmpty)
        XCTAssertEqual(try select([fixture("2.0.0", body: String(repeating: "x", count: 8_000))], channel: .stable)?.notes.count, 5_000)
        XCTAssertThrowsError(try UpdateChecker.selectUpdate(from: [], currentVersion: "broken", channel: .stable))
    }

    func testPreferenceConsentAndDailyCadence() throws {
        let suite = "MSGUpdateTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults, installedVersion: "1.0.0-beta.2")
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(preferences.dailyChecksEnabled)
        XCTAssertFalse(preferences.isDailyCheckDue(at: now))
        XCTAssertEqual(preferences.channel, .includingPrereleases)
        preferences.dailyChecksEnabled = true
        XCTAssertTrue(preferences.isDailyCheckDue(at: now))
        preferences.lastAttempt = now
        XCTAssertFalse(preferences.isDailyCheckDue(at: now.addingTimeInterval(86_399)))
        XCTAssertTrue(preferences.isDailyCheckDue(at: now.addingTimeInterval(86_400)))
        XCTAssertTrue(preferences.isDailyCheckDue(at: now.addingTimeInterval(-1)))
        preferences.channel = .stable
        preferences.lastNotifiedVersion = "2.0.0"
        let reloaded = UpdatePreferences(defaults: defaults, installedVersion: "1.0.0-beta.2")
        XCTAssertEqual(reloaded.channel, .stable)
        XCTAssertEqual(reloaded.lastNotifiedVersion, "2.0.0")
        preferences.dailyChecksEnabled = false
        XCTAssertFalse(preferences.isDailyCheckDue(at: now.addingTimeInterval(100_000)))
        let stableDefaults = try XCTUnwrap(UserDefaults(suiteName: suite + "-stable"))
        defer { stableDefaults.removePersistentDomain(forName: suite + "-stable") }
        XCTAssertEqual(UpdatePreferences(defaults: stableDefaults, installedVersion: "1.0.0").channel, .stable)
    }

    private func select(_ releases: [GitHubRelease], channel: UpdateChannel) throws -> AvailableUpdate? {
        try UpdateChecker.selectUpdate(from: releases, currentVersion: "1.0.0-beta.2", channel: channel)
    }

    private func fixture(_ version: String, beta: Bool = false, draft: Bool = false,
                         published: String? = "2026-10-10T00:00:00Z", assetName: String? = nil,
                         assetState: String = "uploaded", assetSize: Int64 = 1,
                         releaseURL: String? = nil, downloadURL: String? = nil, body: String? = "测试更新说明") -> GitHubRelease {
        let name = assetName ?? "MSG-\(version)-AppleSilicon.dmg"
        return GitHubRelease(tagName: "v" + version, name: "MSG " + version, body: body,
            htmlURL: releaseURL ?? "https://github.com/Dimoo-rich/MacSpaceGuard/releases/tag/v\(version)",
            draft: draft, prerelease: beta, publishedAt: published,
            assets: [.init(name: name, state: assetState, size: assetSize,
                browserDownloadURL: downloadURL ?? "https://github.com/Dimoo-rich/MacSpaceGuard/releases/download/v\(version)/\(name)")])
    }
}
