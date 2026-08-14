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
