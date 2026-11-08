//
//  SKWordWidget.swift
//  WordWidget
//
//  Created by Logout on 16.10.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import WidgetKit
import SwiftUI


struct SKWordWidget: Widget {
    let kindAppIntent: String = "SKWordOfTheDayAppIntent"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kindAppIntent, intent: SKWordWidgetConfigurationIntent.self, provider: SKWordAppIntentTimelineProvider()) { entry in
            SKWordWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(SKLocalization.widgetWordTitle)
        .description(SKLocalization.widgetWordDescriptioon)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
