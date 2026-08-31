////
//  DisplayLanguageUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Choosing the Display Language, which is a workflow no unit test can reach: it starts at an app
/// menu item SwiftUI mounts on its own, opens a separate window, and has to be reachable in the
/// state that made it necessary — Git missing, with `GitUnavailableView` filling the main window.
///
/// The relaunch itself is deliberately not performed: the test asserts up to the restart notice.
///
/// Menus are what make this test's shape unusual, and all three rules below exist for them. Read
/// an open menu with `exists` rather than `waitForExistence`: a menu tracks in its own event loop,
/// so the application never reports itself idle and the waiting form hangs on an item plainly
/// there. Scope every other query by element type: an application-wide `.any` query walks the
/// system menu bar too, whose Apple menu alone carries hundreds of recent-item rows. And reach a
/// row of an open menu from the application rather than through the control that opened it, whose
/// own query stops resolving while its menu is up.
final class DisplayLanguageUITests: XCTestCase {
    /// A throwaway preferences domain. Choosing a language writes `AppleLanguages`, and a test
    /// that wrote it to the app's own domain would change the language of the machine running
    /// it. The name is per-run, so a crashed earlier run cannot seed this one.
    private var suiteName = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        suiteName = "com.anemoris.Colofa.uiTesting.displayLanguage.\(UUID().uuidString)"
        addTeardownBlock { @MainActor [suiteName] in
            // Quit first: the domain belongs to the application, and one still running holds the
            // written value and writes it back out again after this removes it.
            XCUIApplication().terminate()
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
    }

    @MainActor
    func testEnglishSettingsChoosesADisplayLanguageWhileGitIsUnavailable() {
        let application = XCUIApplication.configuredForUITesting(
            additionalArguments: [
                UITestingArgument.gitUnavailable,
                UITestingArgument.settingsDefaultsSuite, suiteName,
            ]
        )
        application.launch()
        application.activate()

        XCTAssertTrue(
            application.staticTexts["Git Is Not Available"].waitForExistence(timeout: 5)
        )

        let appMenu = application.menuBars.menuBarItems["Colofa"]
        appMenu.click()
        let settingsItem = appMenu.menuItems["Settings…"]
        XCTAssertTrue(settingsItem.exists, "The app menu offers no Settings item")
        settingsItem.click()

        // Reached by type and identifier rather than through the Settings window, whose title
        // SwiftUI localizes and whose own identifier belongs to the framework. Nothing else in
        // the app carries this identifier, so finding it is what proves the window opened.
        let picker = application.popUpButtons["settings.displayLanguage"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "Settings opened no Display Language picker while Git was unavailable"
        )

        // Every language the app ships, each named in itself, plus following the system.
        picker.click()
        for label in ["Follow System", "English", "日本語", "한국어", "简体中文", "繁體中文"] {
            XCTAssertTrue(
                picker.menuItems[label].exists,
                "The Display Language picker offers no “\(label)”"
            )
        }
        application.menuItems["日本語"].click()

        // A menu keeps tracking for a moment after one of its rows is clicked, and while it
        // does the application reports only the menu; wait for the window's own controls to come
        // back before reading them. Polled rather than waited on for idle, which an application
        // still tracking a menu never reports.
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == true"), on: picker, timeout: 20),
            "The Display Language picker did not come back"
        )
        XCTAssertEqual(picker.value as? String, "日本語", "The picker did not keep the choice")

        // UI tests launch the app in English, so a chosen Japanese is always a language the
        // running window is not in, whatever language the machine running this is set to.
        let relaunch = application.buttons["settings.relaunchNotice"]
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == true"), on: relaunch, timeout: 10),
            "Choosing another language raised no restart notice"
        )
        XCTAssertTrue(relaunch.isEnabled, "Relaunch is refused with no Git operation running")
    }
}
