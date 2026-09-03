////
//  XCTestCase+Tooltip.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import AppKit
import XCTest

extension XCTestCase {
    /// Asserts that resting the pointer on `element` puts a tooltip on the screen below it.
    ///
    /// macOS draws a tooltip in a panel of its own that is not part of the application's
    /// accessibility hierarchy, so no `XCUIElement` attribute reports one and no query finds its
    /// text. What a test can do is look: photograph the strip of screen a tooltip would cover
    /// while the pointer is somewhere else, move the pointer onto `element`, and photograph the
    /// same strip until it changes.
    ///
    /// The strip deliberately starts below `element` rather than including it. A toolbar item
    /// running a command draws a spinner, and a strip containing one differs from itself frame to
    /// frame — which would pass this assertion for a control showing no tooltip at all.
    ///
    /// This asserts that a tooltip is delivered, not what it says. The copy is asserted where it
    /// can be read: the unavailability-reason suites cover which message each state resolves to,
    /// and `LocalizationLiteralTests` covers its coming from the String Catalog.
    ///
    /// - Parameters:
    ///   - element: The control to hover.
    ///   - resting: Somewhere inert to park the pointer first, outside the strip, so the "before"
    ///     photograph is taken with no tooltip of its own on screen.
    @MainActor
    func assertShowsTooltip(
        over element: XCUIElement,
        parkedOn resting: XCUIElement,
        _ message: @autoclosure () -> String = "",
        timeout: TimeInterval = 8,
        line: UInt = #line
    ) {
        guard let strip = tooltipStrip(below: element) else {
            XCTFail(
                "Could not work out where a tooltip for this control would be drawn",
                file: #filePath,
                line: line
            )
            return
        }

        resting.hover()
        Thread.sleep(forTimeInterval: 0.4)
        guard let before = screenPixels(in: strip) else {
            XCTFail("Could not photograph the screen", file: #filePath, line: line)
            return
        }

        element.hover()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let after = screenPixels(in: strip), differ(before, after) {
                return
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail(message(), file: #filePath, line: line)
    }

    /// The strip of screen a tooltip for `element` would be drawn in, in screenshot pixels.
    ///
    /// macOS puts the tooltip just below the pointer and extends it to the right, shifting it
    /// left only where the screen runs out. The strip is wide enough for the longest of Colofa's
    /// unavailability reasons and tall enough for one that wraps to two lines.
    @MainActor
    private func tooltipStrip(below element: XCUIElement) -> CGRect? {
        guard let screen = NSBitmapImageRep(data: XCUIScreen.main.screenshot().pngRepresentation),
              // Element frames are in points and the screenshot is in pixels. The display
              // carrying the menu bar is the one `XCUIScreen.main` photographs.
              let points = NSScreen.screens.first?.frame.width, points > 0 else {
            return nil
        }
        // Room to the left of the pointer for a tooltip the right edge of the screen pushed back,
        // width for the longest unavailability reason, and height for one that wraps to two
        // lines. The gap keeps the item itself, and a spinner it may be drawing, out of the strip.
        let leadingRoom = 300.0
        let stripWidth = 640.0
        let stripHeight = 90.0
        let gapBelowItem = 4.0

        let scale = Double(screen.pixelsWide) / points
        let frame = element.frame
        let strip = CGRect(
            x: (frame.midX - leadingRoom) * scale,
            y: (frame.maxY + gapBelowItem) * scale,
            width: stripWidth * scale,
            height: stripHeight * scale
        )
        let bounds = CGRect(x: 0, y: 0, width: screen.pixelsWide, height: screen.pixelsHigh)
        let clamped = strip.intersection(bounds).integral
        return clamped.width > 0 && clamped.height > 0 ? clamped : nil
    }

    /// The pixels of `rect`, in a known layout so two photographs can be compared byte for byte.
    @MainActor
    private func screenPixels(in rect: CGRect) -> [UInt8]? {
        let screenshot = XCUIScreen.main.screenshot()
        guard let source = NSBitmapImageRep(data: screenshot.pngRepresentation)?.cgImage,
              let cropped = source.cropping(to: rect) else {
            return nil
        }
        let width = cropped.width
        let height = cropped.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return
            }
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    /// Whether two photographs of the same strip differ by more than rendering noise.
    ///
    /// A tooltip is an opaque panel covering a few percent of the strip. One percent of it is far
    /// more than antialiasing moves and far less than the shortest message Colofa shows.
    private func differ(_ before: [UInt8], _ after: [UInt8]) -> Bool {
        guard before.count == after.count, !before.isEmpty else {
            return false
        }
        var changed = 0
        for index in before.indices where abs(Int(before[index]) - Int(after[index])) > 8 {
            changed += 1
        }
        return changed * 100 > before.count
    }
}
