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
    // Kept from the former AppIntentConfiguration so widgets already on users' home screens
    // keep working after the update.
    let kind: String = "SKWordOfTheDayAppIntent"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SKWordTimelineProvider()) { entry in
            SKWordWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(SKLocalization.widgetWordTitle)
        .description(SKLocalization.widgetWordDescriptioon)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
