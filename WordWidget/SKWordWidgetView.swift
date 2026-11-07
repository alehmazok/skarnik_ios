//
//  SKWordWidgetView.swift
//  WordWidget
//
//  Created by Logout on 17.10.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import SwiftUI
import WidgetKit
import Foundation

struct SKWordWidgetView : View {
    var entry: SKWordWidgetEntry

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    self.textWord
                        .foregroundStyle(Color.accent)
                    self.textTranslation
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.deepLinkURL)
    }
    
    var textWord: some View {
        Text(entry.word.uppercased())
            .lineLimit(2)
            .font(.system(size: 12, weight: .bold))
    }
    
    var textTranslation: some View {
        Text(entry.wordTranslation)
            .font(.system(size: 14))
            .fontWeight(.regular)
    }
}
