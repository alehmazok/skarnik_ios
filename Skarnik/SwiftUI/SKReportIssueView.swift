//
//  SKReportIssueView.swift
//  Skarnik
//

import SwiftUI

struct SKReportIssueView: View {

    enum IssueType: String, CaseIterable, Identifiable {
        case translationError
        case spellingError
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .translationError: return SKLocalization.reportIssueTypeTranslation
            case .spellingError:    return SKLocalization.reportIssueTypeSpelling
            case .other:            return SKLocalization.reportIssueTypeOther
            }
        }
    }

    let word: SKWord?
    let translationUrl: String?
    /// Closes the sheet. UIKit presents this view in a `UIHostingController`,
    /// so the presenter passes its own dismiss instead of relying on
    /// `@Environment(\.dismiss)` reaching the UIKit presentation.
    var onDismiss: (@MainActor () -> Void)? = nil

    @Environment(\.dismiss) private var dismissAction
    @State private var selectedIssue: IssueType = .translationError
    @State private var details: String = ""

    var body: some View {
        NavigationStack {
            formContent
                .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            Section {
                Picker(SKLocalization.reportIssueTitle, selection: $selectedIssue) {
                    ForEach(IssueType.allCases) { issue in
                        Text(issue.title).tag(issue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section(header: Text(SKLocalization.reportIssueDetailsPlaceholder)) {
                TextEditor(text: $details)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 160)
            }
        }
        .navigationTitle(SKLocalization.reportIssueTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: sendReport) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                }
            }
        }
    }

    private func dismiss() {
        if let onDismiss {
            onDismiss()
        } else {
            dismissAction()
        }
    }

    private func sendReport() {
        let wordName = word?.word ?? ""
        let subject = "Памылка ў Скарніку: \(wordName)"
        let body = [
            "Слова: \(wordName)",
            "Спасылка: \(translationUrl ?? "—")",
            "Тып праблемы: \(selectedIssue.title)",
            details.isEmpty ? nil : "Падрабязнасці: \(details)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        if let url = SKSupportMail.url(subject: subject, body: body + "\n\n" + SKSupportMail.currentFooter()) {
            UIApplication.shared.open(url)
        }
        dismiss()
    }

    /// Percent-encodes one mailto query value. `.urlQueryAllowed` keeps `&`, `=`, `+`
    /// and `?` literal, which would split the value into extra query keys.
    nonisolated static func mailtoEncoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

// MARK: - Support mail

/// Mail to the developers: «Напісаць распрацоўшчыкам» in Пра Скарнік and the issue report.
/// The body ends with app and device details, which the user sees before sending.
enum SKSupportMail {
    static let address = "skarnikapp@gmail.com"

    static func url(subject: String?, body: String) -> URL? {
        var query: [String] = []
        if let subject { query.append("subject=\(SKReportIssueView.mailtoEncoded(subject))") }
        query.append("body=\(SKReportIssueView.mailtoEncoded(body))")
        return URL(string: "mailto:\(address)?\(query.joined(separator: "&"))")
    }

    /// «Скарнік 3.8.0 (77)» / «iOS 26.1 · iPhone17,1» under a separator line.
    static func footer(appVersion: String, build: String, systemName: String, systemVersion: String,
                       deviceModel: String) -> String {
        "—\nСкарнік \(appVersion) (\(build))\n\(systemName) \(systemVersion) · \(deviceModel)"
    }

    @MainActor
    static func currentFooter() -> String {
        let info = Bundle.main.infoDictionary
        let device = UIDevice.current
        return footer(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            deviceModel: modelIdentifier()
        )
    }

    /// Hardware id such as «iPhone17,1» (UIDevice.model only says «iPhone»); the simulated model on a simulator.
    static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
