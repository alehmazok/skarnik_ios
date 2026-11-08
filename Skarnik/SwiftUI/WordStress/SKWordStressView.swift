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
            ForEach(self.viewModel.table) { row in
                self.row(row)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
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
