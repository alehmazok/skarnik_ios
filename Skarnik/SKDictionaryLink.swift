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

    /// Kept so the real-time listener stays registered for the app's lifetime.
    private var updates: ConfigUpdateListenerRegistration?
    /// The activated values the app reads, copied out of Firebase off the main thread: Firebase's own
    /// reads wait on its internal queue (busy while it loads, fetches or activates), and the word
    /// screen reads the placement on the main thread every time a word opens.
    private let lock = NSLock()
    private var placement: SKDictionaryLinkPlacement = .defaultPlacement
    private let readQueue = DispatchQueue(label: "by.mazokaleh.Skarnik.remoteConfig", qos: .utility)

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
        guard !SKUITesting.isActive else { return }
        // The values activated at an earlier launch apply until the fetch lands.
        refresh(config)
        config.fetchAndActivate { [weak self] _, error in
            // Offline is common; the stored or default values stay.
            if let error { print("Remote Config fetch failed: \(error.localizedDescription)") }
            self?.refresh(config)
        }
        // Real-time: the backend pushes a change as soon as it is published; activate it at once, so
        // it applies from the next word opened.
        updates = config.addOnConfigUpdateListener { [weak self] update, error in
            if let error {
                print("Remote Config real-time update failed: \(error.localizedDescription)")
                return
            }
            guard update != nil else { return }
            config.activate { _, error in
                if let error { print("Remote Config activate failed: \(error.localizedDescription)") }
                self?.refresh(config)
            }
        }
    }

    /// Copies the activated values on a background queue.
    private func refresh(_ config: RemoteConfig) {
        readQueue.async { [weak self] in
            let value = config.configValue(forKey: Self.dictionaryLinkPlacementKey).stringValue
            let placement = SKDictionaryLinkPlacement(configValue: value)
            guard let self else { return }
            self.lock.lock()
            self.placement = placement
            self.lock.unlock()
        }
    }

    /// Read when a word opens, so a newly activated value applies from the next word. Never blocks.
    var dictionaryLinkPlacement: SKDictionaryLinkPlacement {
        lock.lock()
        defer { lock.unlock() }
        return placement
    }
}
