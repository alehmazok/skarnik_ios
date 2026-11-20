//
//  SKWordStressView.swift
//  Skarnik
//
//  Created by Logout on 10.11.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import SwiftUI

struct SKWordStressView: View {
    let viewModel: SKWordStressViewModel
    var body: some View {
        ZStack {
            self.background
            Group {
                if self.viewModel.isLoading {
                    ProgressView()
                } else {
                    if let error = self.viewModel.error {
                        Text(error)
                            .font(.body)
                            .accessibilityIdentifier("wordStress.error")
                            .frame(maxWidth: 300)
                            .padding()
                    } else {
                        self.list
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wordStress")
        .navigationTitle(self.viewModel.presentTitle)
    }
    
    var background: some View {
        Color(uiColor: UIColor.secondarySystemBackground)
            .ignoresSafeArea()
    }
    
    var list: some View {
        List {
            self.header
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            ForEach(self.viewModel.table) { row in
                self.row(row)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
    
    /// The word the table is for, with the full meaning the picker sheet cuts to two lines.
    var header: some View {
        let entry = self.viewModel.entry
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(SKStressWordPicker.highlightedWord(entry.word))
                    .font(.system(size: 28, weight: .semibold))
                if let partOfSpeech = entry.wordTypeLabel {
                    Text(partOfSpeech)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(uiColor: .tertiarySystemFill)))
                }
            }
            if let meaning = entry.meaning {
                Text(meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .tertiarySystemBackground)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wordStress.header")
    }

    @ViewBuilder
    func row(_ element: SKStressRow) -> some View {
        HStack(content: {
            SKHtmlTextView(html: element.title)
                .accessibilityIdentifier("wordStress.cell")
                .frame(minWidth: 0, maxWidth: .infinity)

            SKHtmlTextView(html: element.content)
                .frame(minWidth: 0, maxWidth: .infinity)

        })
        .catalystVerticalPadding()
    }
}
