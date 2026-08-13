////
//  XCUIElement+WaitForValue.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

extension XCUIElement {
    /// Waits until the element's accessibility value is a non-empty string other than `value`.
    ///
    /// `waitForExistence(timeout:)` only covers elements appearing. Assertions about a control that
    /// stays on screen while its value changes need to poll instead, otherwise they race the
    /// asynchronous Repository load.
    func waitForValue(differingFrom value: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let current = (element as? XCUIElement)?.value as? String else {
                return false
            }
            return !current.isEmpty && current != value
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
