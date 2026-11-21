//
//  SKWordDetailsViewController.swift
//  Skarnik
//
//  Created by Logout on 11.10.22.
//

import SwiftUI
import UIKit

class SKWordDetailsViewController: UIHostingController<SKWordDetailsView> {

    let viewModel: SKWordDetailsViewModel

    required init?(coder: NSCoder) {
        let vm = SKWordDetailsViewModel(translationSource: SKFallbackTranslationSource.sharedWithLocalCache)
        self.viewModel = vm
        super.init(coder: coder, rootView: SKWordDetailsView(viewModel: vm))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView = SKWordDetailsView(
            viewModel: viewModel,
            onSpellingWord: { [weak self] word in self?.openSpellingWord(word) },
            onReport: { [weak self] in self?.presentReport() }
        )
    }

    /// In-flight «На́ціск» lookup; one at a time, dropped when the word changes.
    private var stressLookupTask: Task<Void, Never>?

    var word: SKWord? {
        get { viewModel.word }
        set {
            stressLookupTask?.cancel()
            stressLookupTask = nil
            viewModel.updateWord(newValue)
        }
    }

    var entryPoint: String {
        get { viewModel.entryPoint }
        set { viewModel.entryPoint = newValue }
    }

    func onReport() {
        presentReport()
    }

    // MARK: - Private

    private func presentReport() {
        let reportView = SKReportIssueView(
            word: viewModel.word,
            translationUrl: viewModel.translation?.url,
            onDismiss: { [weak self] in self?.dismiss(animated: true) }
        )
        let hostingController = UIHostingController(rootView: reportView)
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(hostingController, animated: true)
    }

    private func openSpellingWord(_ word: String) {
        guard stressLookupTask == nil else { return }
        SKAnalyticsManager.logStressClicked(word: word)

        stressLookupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.stressLookupTask = nil }
            let result = await SKStressResolver.shared.resolveWordList(word)
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let entries):
                if entries.count > 1 {
                    self.presentSpellingWordPicker(entries)
                } else if let entry = entries.first {
                    self.pushWordStress(entry)
                }
            case .notFound:
                self.presentStressMessage(SKLocalization.wordStressNotFound)
            case .error:
                self.presentStressMessage(SKLocalization.wordStressError)
            }
        }
    }

    // Homonyms (e.g. "а" as noun/conjunction/preposition/...) share a lemma but resolve to
    // different word IDs with different stress/spelling data, so the user must pick which
    // one they mean rather than us guessing the first one back.
    private func presentSpellingWordPicker(_ candidates: [SKStressWordEntry]) {
        present(stressWordPicker(for: candidates), animated: true)
    }

    func stressWordPicker(for candidates: [SKStressWordEntry]) -> UIViewController {
        var didSelect = false
        let pickerView = SKStressWordPickerView(
            entries: candidates,
            onSelect: { [weak self] entry in
                guard !didSelect else { return }
                didSelect = true
                self?.dismiss(animated: true) { [weak self] in
                    self?.pushWordStress(entry)
                }
            },
            onDismiss: { [weak self] in self?.dismiss(animated: true) }
        )
        let hostingController = UIHostingController(rootView: pickerView)
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        return hostingController
    }

    private func presentStressMessage(_ message: String) {
        present(stressMessageAlert(message), animated: true)
    }

    func stressMessageAlert(_ message: String) -> UIAlertController {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: SKLocalization.aboutDone, style: .default))
        return alertController
    }

    private func pushWordStress(_ entry: SKStressWordEntry) {
        let wordStressViewModel = SKWordStressViewModel(entry)
        let wordStressView = SKWordStressView(viewModel: wordStressViewModel)
        let wordStressViewController = UIHostingController(rootView: wordStressView)
        navigationController?.pushViewController(wordStressViewController, animated: true)
    }
}
