//
//  SKStressWordPickerView.swift
//  Skarnik
//
//  Homonym picker for «На́ціск»: when a lemma resolves to several stress entries
//  (e.g. "пара" → па́ра / па́ра / пара́), the user picks one by its stressed form,
//  meaning and part of speech before the stress table opens.
//

import SwiftUI

// MARK: - Model

struct SKStressWordPickerRow: Identifiable, Equatable {
    let entry: SKStressWordEntry
    /// The meaning when known, else the part of speech, else the stressed word.
    let title: String
    /// Part-of-speech chip, shown under a meaning (never next to a bare part-of-speech title).
    let chip: String?
    /// 1-based number among rows of a section that would otherwise read the same.
    let ordinal: Int?

    var id: String { "\(entry.source.rawValue)-\(entry.id)" }
}

struct SKStressWordPickerSection: Identifiable, Equatable {
    /// The stressed form shared by every row, e.g. "па́ра".
    let word: String
    let rows: [SKStressWordPickerRow]

    var id: String { word }
}

enum SKStressWordPicker {
    /// Groups entries by stressed form, in the order the API returned them.
    static func sections(for entries: [SKStressWordEntry]) -> [SKStressWordPickerSection] {
        var order: [String] = []
        var groups: [String: [SKStressWordEntry]] = [:]
        for entry in entries {
            if groups[entry.word] == nil { order.append(entry.word) }
            groups[entry.word, default: []].append(entry)
        }
        return order.map { word in
            SKStressWordPickerSection(word: word, rows: rows(for: groups[word] ?? []))
        }
    }

    private static func rows(for entries: [SKStressWordEntry]) -> [SKStressWordPickerRow] {
        let titled = entries.map { entry -> (SKStressWordEntry, String, String?) in
            if let meaning = entry.meaning {
                return (entry, meaning, entry.wordTypeLabel)
            }
            return (entry, entry.wordTypeLabel ?? entry.word, nil)
        }
        // Without meanings (e.g. the cloud fallback) two homonyms can read identically;
        // number them so the rows stay distinguishable.
        var totals: [String: Int] = [:]
        for (_, title, chip) in titled { totals[key(title, chip), default: 0] += 1 }
        var seen: [String: Int] = [:]
        return titled.map { entry, title, chip in
            let k = key(title, chip)
            var ordinal: Int?
            if (totals[k] ?? 0) > 1 {
                seen[k, default: 0] += 1
                ordinal = seen[k]
            }
            return SKStressWordPickerRow(entry: entry, title: title, chip: chip, ordinal: ordinal)
        }
    }

    private static func key(_ title: String, _ chip: String?) -> String { "\(title)\u{1F}\(chip ?? "")" }

    /// The stressed form with the stressed vowel (the character carrying U+0301) in the accent color.
    static func highlightedWord(_ word: String) -> AttributedString {
        var result = AttributedString()
        for character in word {
            var part = AttributedString(String(character))
            if character.unicodeScalars.contains("\u{0301}") {
                part.foregroundColor = Color.accentColor
            }
            result += part
        }
        return result
    }
}

// MARK: - View

struct SKStressWordPickerView: View {
    let entries: [SKStressWordEntry]
    var onSelect: (SKStressWordEntry) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    private var sections: [SKStressWordPickerSection] { SKStressWordPicker.sections(for: entries) }

    /// No entry carries a meaning (the cloud fallback, or empty meanings from the primary API).
    private var showsNoMeaningsNote: Bool {
        !entries.isEmpty && entries.allSatisfy { $0.meaning == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                let sections = self.sections
                if sections.count == 1, let only = sections.first {
                    sameStressBanner(only.word)
                    card(only.rows)
                } else {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                if showsNoMeaningsNote {
                    Text(SKLocalization.stressPickerNoMeanings)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wordStressPicker")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(SKLocalization.stressPickerTitle)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(uiColor: .tertiarySystemFill)))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(SKLocalization.stressPickerClose)
            .accessibilityIdentifier("wordStressPicker.close")
        }
        .padding(.leading, 4)
        .padding(.trailing, -8)
    }

    private func sameStressBanner(_ word: String) -> some View {
        let wordText = Text(SKStressWordPicker.highlightedWord(word))
            .font(.system(size: 34, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        let hint = Text(SKLocalization.stressPickerSameStress)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                wordText.fixedSize()
                hint
            }
            VStack(alignment: .leading, spacing: 6) {
                wordText
                hint
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .accessibilityElement(children: .combine)
    }

    private func sectionView(_ section: SKStressWordPickerSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(SKStressWordPicker.highlightedWord(section.word))
                    .font(.system(size: 28, weight: .semibold))
                let meanings = section.rows.filter { $0.entry.meaning != nil }.count
                if meanings > 0 {
                    Text(SKLocalization.stressPickerMeaningCount(meanings))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            card(section.rows)
        }
    }

    private func card(_ rows: [SKStressWordPickerRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().padding(.leading, 14)
                }
                rowButton(row)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func rowButton(_ row: SKStressWordPickerRow) -> some View {
        Button {
            onSelect(row.entry)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let chip = row.chip {
                        Text(chip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(uiColor: .tertiarySystemFill)))
                    }
                }
                Spacer(minLength: 0)
                if let ordinal = row.ordinal {
                    Text("\(ordinal)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: row))
        .accessibilityIdentifier("wordStressPicker.row")
    }

    private func accessibilityLabel(for row: SKStressWordPickerRow) -> String {
        [row.entry.word, row.title, row.chip, row.ordinal.map { "\($0)" }]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
