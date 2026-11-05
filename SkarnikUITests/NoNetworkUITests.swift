//
//  NoNetworkUITests.swift
//  SkarnikUITests
//
//  Runs only in the BrowserStack build with networkProfile "no-network" (see
//  scripts/browserstack-run.sh). Every other run skips this class.
//

import XCTest

final class NoNetworkUITests: SkarnikUITestCase {

    /// Search still works offline (bundled index); the translation shows the network error and a
    /// retry that fails the same way instead of hanging or crashing.
    func testWordShowsNetworkErrorWithRetry() {
        openWord("мова", in: .belRus)

        let error = waitFor(element("wordDetailsError"), timeout: 45, "No error state without network")
        XCTAssertTrue(error.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Памылка сеткі")).count > 0,
                      "Error is not the network error")

        let retry = waitFor(app.buttons["Паспрабаваць яшчэ"], "No retry button")
        retry.tap()
        waitFor(element("wordDetailsError"), timeout: 45, "Retry did not end in the error state again")
        XCTAssertFalse(element("wordDetails.translation").exists)
    }
}
