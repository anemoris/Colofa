////
//  LayoutMetrics.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

enum LayoutMetrics {
    static let minimumSidebarWidth = 200.0
    static let idealSidebarWidth = 228.0
    static let maximumSidebarWidth = 300.0

    static let minimumContentWidth = 264.0
    static let idealContentWidth = 320.0
    static let maximumContentWidth = 440.0

    static let minimumDetailWidth = 420.0
    static let idealDetailWidth = 620.0

    static let minimumInspectorWidth = 260.0
    static let idealInspectorWidth = 296.0
    static let maximumInspectorWidth = 380.0
    static let maximumFailureDetailsHeight = 160.0

    static let minimumWindowWidth = 940.0
    static let minimumWindowHeight = 580.0
    static let defaultWindowWidth = 1180.0
    static let defaultWindowHeight = 720.0

    /// The Diff pane's own density. Dense code review needs tighter spacing than the system
    /// defaults give, so it is grouped rather than mixed into the window's dimensions above.
    enum Diff {

        /// Wide enough for a six-figure line number, which is the largest a rendered patch can reach
        /// under the hard limit.
        static let lineNumberWidth = 46.0
        static let markerWidth = 14.0
        static let rowVerticalPadding = 1.0

        /// Changed lines are tinted rather than filled, so the code stays the strongest thing on the
        /// row and the tint survives both appearances and increased contrast.
        static let rowBackgroundOpacity = 0.12

        /// The inset of every band that spans a row's width — the file header and the Hunk header —
        /// so they begin where the gutter does.
        static let bandHorizontalPadding = 8.0
        static let bandVerticalPadding = 6.0
        static let hunkHeaderVerticalPadding = 4.0

        static let sectionSpacing = 16.0
        static let contentSpacing = 6.0
        static let labelSpacing = 4.0
        static let captionSpacing = 2.0
    }
}
