////
//  XCTestCase+Interaction.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import AppKit
import XCTest

extension XCTestCase {
    /// Replaces the contents of `field` with `text`, confirming the field actually reports it.
    ///
    /// The text is pasted rather than typed. `typeText` feeds synthesized key events through
    /// whatever input source is active, so on a machine with a CJK input method "Ada Lovelace"
    /// arrives as "A大Lovelace" — the space commits an IME candidate instead of reaching the
    /// field. Git accepts spaces in configuration values and Commit Summaries, so the tests keep
    /// using realistic values instead of avoiding the character.
    ///
    /// The system pasteboard is restored during test teardown.
    @MainActor
    func replaceText(
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
            paste(text, into: field)
        }
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "value == %@", text), on: field),
            "Field reports “\(field.value ?? "")” after entering “\(text)”",
            file: #filePath,
            line: line
        )
    }

    /// Replaces the contents of a secure `field` with `text`.
    ///
    /// A secure field reports its contents masked, so what it reports is checked for length and
    /// deliberately never against the text itself: a field that echoed a secret back would be the
    /// defect this asserts the absence of.
    @MainActor
    func replaceSecureText(
        of field: XCUIElement,
        with text: String,
        line: UInt = #line
    ) {
        field.click()
        field.typeKey("a", modifierFlags: [.command])
        paste(text, into: field)

        let reported = field.value as? String ?? ""
        XCTAssertEqual(
            reported.count,
            text.count,
            "Secure field reports \(reported.count) characters after entering \(text.count)",
            file: #filePath,
            line: line
        )
        XCTAssertNotEqual(
            reported,
            text,
            "A secure field showed what was typed",
            file: #filePath,
            line: line
        )
    }

    /// Pastes rather than types, for the reason `replaceText(of:with:)` explains. The system
    /// pasteboard is restored during test teardown.
    ///
    /// - Parameter element: What receives the paste. Passing the application rather than a field
    ///   sends it wherever keyboard focus already is, which is how a test asserts where a window
    ///   opened focused without clicking anything first.
    @MainActor
    func paste(_ text: String, into element: XCUIElement) {
        let pasteboard = NSPasteboard.general
        let previousItems: [NSPasteboardWriting] = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy as NSPasteboardWriting
        } ?? []
        addTeardownBlock {
            pasteboard.clearContents()
            pasteboard.writeObjects(previousItems)
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        element.typeKey("v", modifierFlags: [.command])
    }

    /// Waits for `element` to exist by polling, rather than `waitForExistence`, which first
    /// waits for the application to go idle and can time out on a view that is plainly there.
    @MainActor
    func assertEventuallyExists(
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
    func waitUntil(
        _ predicate: NSPredicate,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
