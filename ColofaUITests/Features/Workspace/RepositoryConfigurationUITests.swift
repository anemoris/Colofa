////
//  RepositoryConfigurationUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import AppKit
import XCTest

final class RepositoryConfigurationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEnglishReadsAndEditsEffectiveConfiguration() {
        let application = XCUIApplication.configuredForRealRepositoryState(
            path: "/tmp/Colofa Configuration"
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["baseline.inspector.toggle"].click()

        XCTAssertTrue(application.staticTexts["Configuration"].waitForExistence(timeout: 2))
        let name = application.textFields["repository.configuration.user.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        XCTAssertEqual(name.value as? String, "")
        XCTAssertTrue(
            application.staticTexts["Inherited from global: Colofa UI Author"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(application.buttons["repository.configuration.save.user.name"].isEnabled)
        assertConfigurationSource(application, key: "user.name", scope: "global", names: "Global")
        assertConfigurationSource(
            application,
            key: "user.email",
            scope: "local",
            names: "This Repository"
        )
        XCTAssertTrue(application.staticTexts["Overrides global “global@example.invalid”."].exists)
        assertConfigurationScopeSwitching(application, nameField: name)
        assertSavingEmailPreservesNameDraft(application, nameField: name)

        replaceText(of: name, with: "Edited Author")
        application.buttons["repository.configuration.save.user.name"].click()

        // The edit must reach the Repository scope, not just stay in the field.
        let savedLocally = application.descendants(matching: .any)[
            "repository.configuration.source.user.name.local"
        ]
        expectation(
            for: NSPredicate(format: "label CONTAINS %@", "Edited Author"),
            evaluatedWith: savedLocally
        )
        waitForExpectations(timeout: 5)
        XCTAssertEqual(name.value as? String, "Edited Author")
    }

    @MainActor
    func testEnglishConfigurationFailureIsPresented() {
        let application = XCUIApplication.configuredForRealRepositoryState(
            path: "/tmp/Colofa Configuration Failure",
            additionalArguments: [UITestingArgument.stageFailure]
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["baseline.inspector.toggle"].click()
        let name = application.textFields["repository.configuration.user.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        replaceText(of: name, with: "Unsaveable Author")
        application.buttons["repository.configuration.save.user.name"].click()

        assertEventuallyExists(application.staticTexts["Configuration Could Not Be Saved"])
    }

    @MainActor
    private func selectConfigurationScope(
        _ title: String,
        in application: XCUIApplication
    ) {
        application.descendants(matching: .any)["repository.configuration.scope"].click()
        application.menuItems[title].click()
    }

    @MainActor
    private func assertConfigurationScopeSwitching(
        _ application: XCUIApplication,
        nameField: XCUIElement
    ) {
        selectConfigurationScope("Global", in: application)
        let email = application.textFields["repository.configuration.user.email"]
        expectation(
            for: NSPredicate(format: "value == %@", "global@example.invalid"),
            evaluatedWith: email
        )
        waitForExpectations(timeout: 5)
        XCTAssertEqual(nameField.value as? String, "Colofa UI Author")
        XCTAssertTrue(
            application.staticTexts[
                "This Repository overrides this value with “local@example.invalid”."
            ].exists
        )

        selectConfigurationScope("This Repository", in: application)
        expectation(for: NSPredicate(format: "value == %@", ""), evaluatedWith: nameField)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func assertSavingEmailPreservesNameDraft(
        _ application: XCUIApplication,
        nameField: XCUIElement
    ) {
        replaceText(of: nameField, with: "Unsaved Author")

        let email = application.textFields["repository.configuration.user.email"]
        replaceText(of: email, with: "not-an-email")
        assertEventuallyExists(
            application.staticTexts[
                "This does not look like a conventional email address. Git may still accept it."
            ],
            "An unconventional email address must warn without blocking the save."
        )

        replaceText(of: email, with: "edited@example.invalid")
        application.buttons["repository.configuration.save.user.email"].click()

        let savedEmail = application.descendants(matching: .any)[
            "repository.configuration.source.user.email.local"
        ]
        expectation(
            for: NSPredicate(format: "label CONTAINS %@", "edited@example.invalid"),
            evaluatedWith: savedEmail
        )
        waitForExpectations(timeout: 5)
        XCTAssertEqual(nameField.value as? String, "Unsaved Author")

        // Clearing the field unsets the key at this scope, so the Repository source disappears
        // and the global value is inherited again.
        replaceText(of: email, with: "")
        application.buttons["repository.configuration.save.user.email"].click()

        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == false"), on: savedEmail),
            "Clearing the field must unset the Repository value, not store an empty string."
        )
        assertEventuallyExists(
            application.staticTexts["Inherited from global: global@example.invalid"]
        )
        XCTAssertEqual(nameField.value as? String, "Unsaved Author")
    }

    /// Replaces the contents of `field` with `text`, confirming the field actually reports it.
    ///
    /// The text is pasted rather than typed. `typeText` feeds synthesized key events through
    /// whatever input source is active, so on a machine with a CJK input method "Ada Lovelace"
    /// arrives as "A大Lovelace" — the space commits an IME candidate instead of reaching the
    /// field. Git accepts spaces in configuration values and `user.name` almost always has one,
    /// so the tests keep using realistic values instead of avoiding the character.
    ///
    /// This replaces the system pasteboard contents.
    @MainActor
    private func replaceText(
        of field: XCUIElement,
        with text: String,
        line: UInt = #line
    ) {
        field.click()
        field.typeKey("a", modifierFlags: [.command])
        if text.isEmpty {
            // Selecting all does not remove anything on its own.
            field.typeKey(.delete, modifierFlags: [])
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            field.typeKey("v", modifierFlags: [.command])
        }
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "value == %@", text), on: field),
            "Field reports “\(field.value ?? "")” after entering “\(text)”",
            file: #filePath,
            line: line
        )
    }

    /// Waits for `element` to exist by polling, rather than `waitForExistence`, which first
    /// waits for the application to go idle and can time out on a view that is plainly there.
    @MainActor
    private func assertEventuallyExists(
        _ element: XCUIElement,
        _ message: @autoclosure () -> String = "",
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == true"), on: element),
            message(),
            file: #filePath,
            line: line
        )
    }

    @MainActor
    private func waitUntil(
        _ predicate: NSPredicate,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Scope titles are combined into their source row for VoiceOver, so they are not reachable
    /// as standalone static texts; the row is matched by identifier and its label is checked for
    /// the localized scope name.
    @MainActor
    private func assertConfigurationSource(
        _ application: XCUIApplication,
        key: String,
        scope: String,
        names scopeTitle: String,
        line: UInt = #line
    ) {
        let source = application.descendants(matching: .any)[
            "repository.configuration.source.\(key).\(scope)"
        ]
        XCTAssertTrue(source.waitForExistence(timeout: 2), file: #filePath, line: line)
        XCTAssertTrue(
            source.label.contains(scopeTitle),
            "Expected the \(key) \(scope) source to name its scope, got: \(source.label)",
            file: #filePath,
            line: line
        )
    }
}
