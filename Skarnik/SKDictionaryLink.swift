//
//  SKDictionaryLink.swift
//  Skarnik
//
//  The link from a Бел-Рус entry to the same headword in ТСБМ and back, and the Remote Config
//  parameter that places it (an A/B test). Same parameter and rules as skarnik_android
//  (`FindDictionaryLinkUseCase`, ADR 0013).
//

import Foundation
import FirebaseRemoteConfig

/// The variants of the `dictionary_link_placement` experiment, by their Remote Config value.
enum SKDictionaryLinkPlacement: String, CaseIterable {
    /// A button under the headword.
    case header
    /// A row after the translation.
    case footer
    /// No link: the experiment's control group. Not named `none`, which reads as `Optional.none`.
    case hidden = "none"

    /// What the app shows before the first fetch, without an experiment, or for an unknown value.
    static let defaultPlacement: SKDictionaryLinkPlacement = .header

    /// The placement from a Remote Config value; empty or unknown means the default.
    init(configValue: String) {
        let raw = configValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = SKDictionaryLinkPlacement(rawValue: raw) ?? Self.defaultPlacement
    }
}

/// The entry of the same headword in the other dictionary, shown at `placement` (never `.hidden`).
struct SKDictionaryLink: Equatable {
    let target: SKWord
    let placement: SKDictionaryLinkPlacement

    /// The link for `word`, or nil: Рус-Бел (Russian headwords), the control group (no lookup), or no
    /// entry with the same `lword`. About 70% of Бел-Рус and 81% of ТСБМ entries have one.
    static func find(for word: SKWord,
                     placement: SKDictionaryLinkPlacement,
                     index: (SKWord, ESKVocabularyType) -> SKWord? = SKVocabularyIndex.shared.sameWord) -> SKDictionaryLink? {
        guard placement != .hidden, let dictionary = word.lang_id.linkedDictionary,
              let target = index(word, dictionary) else { return nil }
        return SKDictionaryLink(target: target, placement: placement)
    }
}

extension ESKVocabularyType {
    /// The dictionary a translation links to for the same headword: Бел-Рус ⇄ ТСБМ.
    var linkedDictionary: ESKVocabularyType? {
        switch self {
        case .bel_rus: return .bel_definition
        case .bel_definition: return .bel_rus
        default: return nil
        }
    }
}

/// Firebase Remote Config. Fetched and activated at launch, at most every 12 hours (skarnik_android's
/// settings), and kept current while the app runs by real-time updates: a value published in the
/// console arrives within seconds instead of after the 12-hour throttle and a cold start. Reads never
/// fail and fall back to the defaults. Not gated by analytics consent: the fetch sends a Firebase
/// installation id, no events.
final class SKRemoteConfig {
    static let shared = SKRemoteConfig()

    static let dictionaryLinkPlacementKey = "dictionary_link_placement"

    /// Set before `start()` runs, so a read before it is not a crash.
    private var config: RemoteConfig?
    /// Kept so the real-time listener stays registered for the app's lifetime.
    private var updates: ConfigUpdateListenerRegistration?

    /// After `FirebaseApp.configure()`. UI tests skip the fetch, so they always get the defaults.
    func start() {
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 12 * 60 * 60
        settings.fetchTimeout = 60
        config.configSettings = settings
        config.setDefaults([
            Self.dictionaryLinkPlacementKey: SKDictionaryLinkPlacement.defaultPlacement.rawValue as NSObject,
        ])
        self.config = config
        guard !SKUITesting.isActive else { return }
        config.fetchAndActivate { _, error in
            // Offline is common; the stored or default values stay.
            if let error { print("Remote Config fetch failed: \(error.localizedDescription)") }
        }
        // Real-time: the backend pushes a change as soon as it is published; activate it at once, so
        // it applies from the next word opened.
        updates = config.addOnConfigUpdateListener { update, error in
            if let error {
                print("Remote Config real-time update failed: \(error.localizedDescription)")
                return
            }
            guard update != nil else { return }
            config.activate { _, error in
                if let error { print("Remote Config activate failed: \(error.localizedDescription)") }
            }
        }
    }

    /// Read when a word opens, so a value activated by the launch fetch applies from the next word.
    var dictionaryLinkPlacement: SKDictionaryLinkPlacement {
        guard let config else { return .defaultPlacement }
        return SKDictionaryLinkPlacement(configValue: config.configValue(forKey: Self.dictionaryLinkPlacementKey).stringValue)
    }
}
