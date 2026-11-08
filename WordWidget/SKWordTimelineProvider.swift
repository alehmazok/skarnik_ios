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

struct SKWordAppIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SKWordWidgetEntry {
        SKWordWidgetEntry(date: Date(),
                          word: SKLocalization.widgetWordSampleWord,
                          wordTranslation: SKLocalization.widgetWordSampleTranslation)

    }

    func snapshot(for configuration: SKWordWidgetConfigurationIntent, in context: Context) async -> SKWordWidgetEntry {
        SKWordWidgetEntry(date: Date(),
                          word: SKLocalization.widgetWordSampleWord,
                          wordTranslation: SKLocalization.widgetWordSampleTranslation)
    }
    
    private var wordFetchService = SKWordFetchService()
    
    func timeline(for configuration: SKWordWidgetConfigurationIntent, in context: Context) async -> Timeline<SKWordWidgetEntry> {
        // Entry is current now; WidgetKit asks for the next timeline in one hour.
        let now = Date()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        guard let word = await self.wordFetchService.fetchRandomWord(.bel_rus) else {
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
