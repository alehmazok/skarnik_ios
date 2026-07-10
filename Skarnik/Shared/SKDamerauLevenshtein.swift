//
//  SKDamerauLevenshtein.swift
//  Skarnik
//

import Foundation

enum SKDamerauLevenshtein {
    /// Damerau-Levenshtein edit distance (Optimal String Alignment variant) between `a` and `b`.
    /// Insertions, deletions, substitutions, and adjacent transpositions each count as a single edit.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        let lengthA = a.count
        let lengthB = b.count

        if lengthA == 0 { return lengthB }
        if lengthB == 0 { return lengthA }

        var distances = [[Int]](repeating: [Int](repeating: 0, count: lengthB + 1), count: lengthA + 1)

        for i in 0...lengthA { distances[i][0] = i }
        for j in 0...lengthB { distances[0][j] = j }

        for i in 1...lengthA {
            for j in 1...lengthB {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1

                let deletion = distances[i - 1][j] + 1
                let insertion = distances[i][j - 1] + 1
                let substitution = distances[i - 1][j - 1] + cost

                var value = min(deletion, insertion, substitution)

                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, distances[i - 2][j - 2] + cost)
                }

                distances[i][j] = value
            }
        }

        return distances[lengthA][lengthB]
    }
}
