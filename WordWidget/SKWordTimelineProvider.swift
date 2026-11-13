//
//  SKWordTimelineProvider.swift
//  WordWidget
//
//  Created by Logout on 17.10.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import Foundation
import WidgetKit
import SwiftUI

// The widget has no settings, so it uses a plain TimelineProvider instead of an
// AppIntentTimelineProvider. An AppIntent-based widget needs WidgetKit to resolve the
// intent through system services first; when that lookup fails ("No AppIntent in
// timeline(for:with:)", seen on iOS 26 simulators) timeline() is never called and the
// widget stays a gray placeholder.
struct SKWordTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SKWordWidgetEntry {
        SKWordWidgetEntry(date: Date(),
                          word: SKLocalization.widgetWordSampleWord,
                          wordTranslation: SKLocalization.widgetWordSampleTranslation)

    }

    func getSnapshot(in context: Context, completion: @escaping (SKWordWidgetEntry) -> Void) {
        completion(SKWordWidgetEntry(date: Date(),
                                     word: SKLocalization.widgetWordSampleWord,
                                     wordTranslation: SKLocalization.widgetWordSampleTranslation))
    }
    
    private var wordFetchService = SKWordFetchService()
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SKWordWidgetEntry>) -> Void) {
        let service = self.wordFetchService
        Task {
            completion(await Self.timeline(using: service))
        }
    }

    private static func timeline(using wordFetchService: SKWordFetchService) async -> Timeline<SKWordWidgetEntry> {
        // Entry is current now; WidgetKit asks for the next timeline in one hour.
        let now = Date()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        guard let word = await wordFetchService.fetchRandomWord(.bel_rus) else {
            let fallback = SKWordWidgetEntry(date: now,
                                             word: SKLocalization.widgetWordSampleWord,
                                             wordTranslation: SKLocalization.widgetWordSampleTranslation)
            return Timeline(entries: [fallback], policy: .after(nextRefresh))
        }
        let entry = SKWordWidgetEntry(date: now,
                                      word: word.word,
                                      wordTranslation: word.translation,
                                      wordId: word.wordId,
                                      language: word.language)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}
