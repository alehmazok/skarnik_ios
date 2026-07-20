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

    var word: SKWord? {
        get { viewModel.word }
        set { viewModel.updateWord(newValue) }
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
        if #available(iOS 14, *) {
            let reportView = SKReportIssueView(
                word: viewModel.word,
                translationUrl: viewModel.translation?.url
            )
            let hostingController = UIHostingController(rootView: reportView)
            if #available(iOS 15, *) {
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                    if #available(iOS 16, *) {
                        sheet.preferredCornerRadius = 20
                    }
                }
            }
            present(hostingController, animated: true)
        }
    }

    private func openSpellingWord(_ word: String) {
        SKAnalyticsManager.logStressClicked(word: word)

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch await SKStressResolver.shared.resolveWordList(word) {
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
        let alertController = spellingWordPickerAlert(for: candidates)
        if let popPresenter = alertController.popoverPresentationController {
            popPresenter.sourceView = view
            popPresenter.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popPresenter.permittedArrowDirections = []
        }
        present(alertController, animated: true)
    }

    func spellingWordPickerAlert(for candidates: [SKStressWordEntry]) -> UIAlertController {
        let alertController = UIAlertController(
            title: SKLocalization.wordDetailsSpellingTitle,
            message: SKLocalization.wordDetailsSpellingMessage,
            preferredStyle: .actionSheet
        )
        for candidate in candidates {
            let title = [candidate.word, candidate.wordTypeLabel].compactMap { $0 }.joined(separator: " — ")
            alertController.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.pushWordStress(candidate)
            })
        }
        alertController.addAction(UIAlertAction(title: SKLocalization.wordDetailsSpellingCancel, style: .cancel))
        return alertController
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
