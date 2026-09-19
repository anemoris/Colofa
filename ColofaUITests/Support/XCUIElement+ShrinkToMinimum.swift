////
//  XCUIElement+ShrinkToMinimum.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

extension XCUIElement {
    /// Drags the window as small as it will go, from inside both edges: an edge flush with the
    /// screen's own has nothing outside it left to click.
    @MainActor
    func shrinkToMinimum() {
        for _ in 0..<2 {
            let bottom = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
                .withOffset(CGVector(dx: 0, dy: -2))
            bottom.click(
                forDuration: 0.3,
                thenDragTo: bottom.withOffset(CGVector(dx: 0, dy: -600)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )

            let trailing = coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: -2, dy: 0))
            trailing.click(
                forDuration: 0.3,
                thenDragTo: trailing.withOffset(CGVector(dx: -600, dy: 0)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )
        }
    }
}
