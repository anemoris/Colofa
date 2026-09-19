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

    /// The detail column's minimum is whatever the window's minimum leaves once the sidebar, the
    /// content column, and the dividers between them are placed.
    ///
    /// The window's minimum width is the columns' minimums added up, not a `.frame(minWidth:)`
    /// around the workspace. Such a frame broke the sidebar's slide: while the sidebar slid in,
    /// the frame still held the rest of the workspace to the full minimum, so in any window
    /// narrower than that minimum plus the sidebar the slide was cut short and snapped to its end
    /// (measured on macOS 27). The split view's own minimums slide cleanly, and in a window too
    /// narrow for the sidebar, showing it widens the window as it slides in.
    static let minimumDetailWidth = minimumWindowWidth - minimumSidebarWidth - minimumContentWidth
        - 2 * dividerWidth
    static let idealDetailWidth = 640.0

    /// The width of the split view's dividers, one between each pair of columns.
    static let dividerWidth = 1.0

    /// Repository Info's panel is a fixed width: it is a plain panel beside the detail view
    /// rather than a resizable system inspector.
    static let inspectorWidth = 296.0
    static let maximumFailureDetailsHeight = 160.0

    static let minimumWindowWidth = 1100.0
    static let minimumWindowHeight = 580.0
    static let defaultWindowWidth = 1200.0
    static let defaultWindowHeight = 720.0

    /// The History pane's own dimensions, kept apart from the window's for the same reason the
    /// Diff pane's are: they answer to the density of a Commit list rather than to a column.
    enum History {

        /// How much of the detail column the Commit's own metadata may take before it scrolls.
        /// A Commit message has no upper bound, and neither the changed paths nor the Diff below
        /// it may be pushed off screen by one.
        static let maximumDetailHeight = 200.0

        /// How much the changed paths may take. They sit above the Diff rather than inside the
        /// scrolling metadata, because choosing one is what the pane is for.
        static let maximumChangedFilesHeight = 160.0
    }

    /// The Stashes pane's and its sheet's own dimensions, kept apart from the window's for the
    /// reason History's are: they answer to the density of a saved-work list rather than to a
    /// column.
    enum Stash {

        /// The sheet is as wide as the New Branch dialog: one text field and two checkboxes read
        /// at that width without either stretching the field or wrapping a checkbox title.
        static let dialogWidth = 420.0

        /// How much of Git's own refusal the sheet shows before it scrolls, so a long message
        /// cannot push the field and its buttons off a sheet.
        static let maximumFailureOutputHeight = 120.0

        /// How much of the detail column the Stash's own metadata may take before it scrolls.
        static let maximumDetailHeight = 200.0

        /// How much the saved paths may take. They sit above the Diff rather than inside the
        /// scrolling metadata, because choosing one is what the pane is for.
        static let maximumChangedFilesHeight = 160.0
    }

    /// The toolbar's own metrics.
    enum Toolbar {

        /// The gap between a remote command's symbol and the ahead/behind count beside it.
        ///
        /// Tighter than a stack's default because the two read as one control: `DESIGN.md` §8
        /// keeps this group narrow enough that New Branch and Stash stay out of the `»` overflow
        /// menu, and a default-width gap on two of the buttons spends that budget on whitespace.
        static let countSpacing = 2.0
    }

    /// The Settings window's own width. A settings pane is sized by its own content rather
    /// than by the workspace window, and one grouped Form holding a picker row reads at this
    /// width without either stretching the row or wrapping its restart notice.
    enum Settings {
        static let width = 460.0
    }

    /// The New Branch dialog's own dimensions. A sheet is sized by its content rather than by
    /// the window it belongs to, so its width lives apart from the window's.
    enum Branch {
        static let dialogWidth = 420.0

        /// How much of Git's own refusal the dialog shows before it scrolls, so a long message
        /// cannot push the name field and its buttons off a sheet.
        static let maximumFailureOutputHeight = 120.0
    }

    /// The Merge confirmation's own dimensions. Wider than the New Branch dialog because it
    /// names two Refs in full and carries a radio group whose longest option must not wrap into
    /// something that reads as two choices.
    enum Merge {
        static let dialogWidth = 460.0
    }

    /// The Fetch Tags dialog's own dimensions. A sheet is sized by its content rather than by
    /// the window it belongs to, so its width lives apart from the window's.
    enum Remote {
        static let dialogWidth = 380.0

        /// The Push confirmation is wider than the Publish question: it shows two Refs in full,
        /// and a Branch or upstream that wrapped would stop reading as the one destination the
        /// user is confirming.
        static let pushDialogWidth = 440.0
    }

    /// The Authentication Request dialog's own dimensions. Wider than the Fetch Tags dialog
    /// because a host key fingerprint is compared character by character and must not wrap into
    /// something that reads as a different value.
    enum Authentication {
        static let dialogWidth = 440.0

        /// How much of a question Colofa could not classify is shown before it scrolls. Such a
        /// prompt is Git's or OpenSSH's own text, bounded only by what the AskPass channel
        /// accepts, and a sheet that grew with it would push the buttons that answer it past the
        /// bottom of the screen.
        static let promptMaxHeight = 160.0
    }

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
