////
//  PasteboardWriter.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import AppKit

/// Puts plain text on the system pasteboard.
///
/// AppKit rather than SwiftUI because SwiftUI's copy affordances are about a focused view's own
/// contents, and a Copy SHA button is copying a value the user selected rather than the text a
/// row happens to render. Kept as a value with one closure so a test can read exactly what a
/// Copy action put on the pasteboard, which is the only part of it worth asserting.
nonisolated struct PasteboardWriter: Sendable {
    let write: @MainActor @Sendable (String) -> Void

    static func live() -> Self {
        Self { text in
            let pasteboard = NSPasteboard.general
            // A pasteboard keeps every representation it was given until it is cleared, so a
            // stale flavour of an earlier copy would otherwise still be pasteable.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }
}
