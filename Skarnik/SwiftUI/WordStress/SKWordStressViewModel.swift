//
//  SKWordStressViewModel.swift
//  Skarnik
//
//  Created by Logout on 10.11.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import Foundation
import Observation

@MainActor
@Observable
final class SKWordStressViewModel {
    var table: [SKStressRow] = []
    var error: String?
    var isLoading: Bool
    private let entry: SKStressWordEntry
    private let resolver: SKStressResolver

    init(_ entry: SKStressWordEntry, resolver: SKStressResolver = .shared) {
        self.entry = entry
        self.resolver = resolver
        self.isLoading = true
        self.fetchTable()
    }

    var presentTitle: String { SKLocalization.wordStressTitle }

    func fetchTable() {
        Task {
            switch await resolver.stressTable(entry) {
            case .success(let rows):
                self.table = rows
                self.isLoading = false
            case .notFound:
                self.error = SKLocalization.wordStressNotFound
                self.isLoading = false
            case .error:
                self.error = SKLocalization.wordStressError
                self.isLoading = false
            }
        }
    }
}
