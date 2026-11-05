//
//  AppDelegate.swift
//  Skarnik
//
//  Created by Logout on 6.10.22.
//

import UIKit
import FirebaseCore
import FirebaseCrashlytics

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
// Override point for customization after application launch.
        
//        Task {
//            let word = SKVocabularyIndex.shared.word("данос", vocabularyType: .bel_rus)!
//            let wordFetch = await SKWordFetchService().fetchWord(word)
//            let status = wordFetch?.isSimilar
//            return
//        }
        
        SKUITesting.prepareForLaunch()

        FirebaseApp.configure()

        SKAnalyticsConsentController.shared.applyStoredConsent()

        SKAnalyticsManager.logAppOpen()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}


// MARK: - UI testing

/// Hooks for `SkarnikUITests` (CI simulator and BrowserStack devices). Inactive unless the test
/// launches the app with `-uiTesting`, so they never change what users get.
enum SKUITesting {
    /// The app was launched by a UI test.
    static let isActive = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    /// Start from a fresh install: no history, bookmarks, settings or offline dictionaries.
    static let resetsState = ProcessInfo.processInfo.arguments.contains("-uiTestingReset")

    /// Runs first in `didFinishLaunching`, before any controller reads its stored state.
    static func prepareForLaunch() {
        guard isActive else { return }
        // Fewer animations means fewer "wait for app to idle" stalls in XCTest.
        UIView.setAnimationsEnabled(false)
        guard resetsState else { return }
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        for suffix in ["", "-wal", "-shm", "-journal"] {
            try? FileManager.default.removeItem(at: support.appendingPathComponent("offline_dictionary.db" + suffix))
        }
    }
}
