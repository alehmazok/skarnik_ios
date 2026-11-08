//
//  SKWhatsNewController.swift
//  Skarnik
//
//  "What's new" after an update: release notes ship inside the app (SKWhatsNewCatalog),
//  and a sheet shows them once on the first launch of a version that has notes.
//  Fresh installs never see the sheet. Settings → «Што новага» lists every release.
//

import Foundation

struct SKWhatsNewItem: Equatable, Identifiable {
    /// SF Symbol name; must exist on the deployment target (iOS 17).
    let symbol: String
    let title: String
    let text: String

    var id: String { title }
}

struct SKWhatsNewRelease: Equatable, Identifiable {
    /// Marketing version (`CFBundleShortVersionString`) the notes belong to, e.g. "3.7.0".
    let version: String
    let items: [SKWhatsNewItem]

    var id: String { version }
}

/// Release notes, newest first. Add an entry in the same PR as a user-visible change,
/// under the version that will ship it. A version without an entry shows no sheet.
enum SKWhatsNewCatalog {
    static let releases: [SKWhatsNewRelease] = [
        SKWhatsNewRelease(version: "3.7.0", items: [
            SKWhatsNewItem(
                symbol: "textformat.size",
                title: "Новы выгляд артыкула",
                text: "Слова паказваецца буйна ў шапцы экрана, а пераклад адкрываецца хутчэй і выглядае акуратней."
            ),
            SKWhatsNewItem(
                symbol: "paintpalette",
                title: "Колеры артыкула",
                text: "У Наладах праграмы можна абраць, як вылучаць словы ў перакладзе: сістэмнымі колерамі альбо чырвоным колерам Скарніка."
            ),
            SKWhatsNewItem(
                symbol: "arrow.clockwise",
                title: "Калі прапала сетка",
                text: "Калі пераклад не загрузіўся, націсніце «Паспрабаваць яшчэ» проста на старонцы слова."
            ),
            SKWhatsNewItem(
                symbol: "magnifyingglass",
                title: "Пошук адным націскам",
                text: "Націсніце на ўкладку «Пошук» яшчэ раз, каб адразу пачаць уводзіць слова."
            ),
            SKWhatsNewItem(
                symbol: "rectangle.on.rectangle",
                title: "Спрытнейшы віджэт",
                text: "Віджэт са словам паказвае новае слова адразу, а не праз гадзіну. Для праграмы цяпер патрэбна iOS 17 ці навейшая."
            ),
        ]),
        SKWhatsNewRelease(version: "3.6.0", items: [
            SKWhatsNewItem(
                symbol: "bookmark",
                title: "Закладкі",
                text: "Захоўвайце словы кнопкай на старонцы слова і знаходзьце іх на асобнай укладцы."
            ),
            SKWhatsNewItem(
                symbol: "text.magnifyingglass",
                title: "Разумнейшы пошук",
                text: "Скарнік знаходзіць слова, нават калі да яго прыляпіўся прыназоўнік ці злучнік."
            ),
        ]),
        SKWhatsNewRelease(version: "3.4.1", items: [
            SKWhatsNewItem(
                symbol: "arrow.down.circle",
                title: "Слоўнікі без інтэрнэту",
                text: "Спампуйце слоўнікі ў Наладах, і пераклады будуць адкрывацца без сеткі."
            ),
        ]),
    ]
}

final class SKWhatsNewController {
    static let shared = SKWhatsNewController()

    static let lastSeenVersionKey = "whatsNewLastSeenVersion"

    /// Keys that only an app which has already been used writes. When none is set and the
    /// last seen version is missing, this launch is a fresh install, not an update.
    static let existingUserKeys = [
        "wordsHistoryKey",
        "favoriteWordsKey",
        "analyticsConsentHasResponded",
        "SKAppstoreReviewController.wordsCompletedCount",
        "offlineDictionaryCursorsKey",
    ]

    let releases: [SKWhatsNewRelease]
    let currentVersion: String
    private let userDefaults: UserDefaults

    init(
        userDefaults: UserDefaults = .standard,
        releases: [SKWhatsNewRelease] = SKWhatsNewCatalog.releases,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    ) {
        self.userDefaults = userDefaults
        self.releases = releases
        self.currentVersion = currentVersion
    }

    /// Call once at app launch, before anything else writes to UserDefaults (the consent
    /// prompt would otherwise make a fresh install look like an update).
    /// Records the current version as seen when there is nothing to show.
    func prepareAtLaunch() {
        let lastSeen = userDefaults.string(forKey: Self.lastSeenVersionKey)
        if lastSeen == nil && !isExistingUser {
            markCurrentVersionSeen()
            return
        }
        if releaseToShow == nil {
            markCurrentVersionSeen()
        }
    }

    /// The newest release the person has not seen yet that is not newer than the running app.
    var releaseToShow: SKWhatsNewRelease? {
        let lastSeen = userDefaults.string(forKey: Self.lastSeenVersionKey)
        return releases
            .filter { Self.compare($0.version, currentVersion) != .orderedDescending }
            .filter { lastSeen == nil || Self.compare($0.version, lastSeen!) == .orderedDescending }
            .max { Self.compare($0.version, $1.version) == .orderedAscending }
    }

    /// Releases for the Settings list: newest first, nothing newer than the running app.
    var history: [SKWhatsNewRelease] {
        releases
            .filter { Self.compare($0.version, currentVersion) != .orderedDescending }
            .sorted { Self.compare($0.version, $1.version) == .orderedDescending }
    }

    func markCurrentVersionSeen() {
        userDefaults.set(currentVersion, forKey: Self.lastSeenVersionKey)
    }

    private var isExistingUser: Bool {
        Self.existingUserKeys.contains { userDefaults.object(forKey: $0) != nil }
    }

    /// Numeric comparison of dotted versions; missing parts count as 0 ("3.7" == "3.7.0").
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
