////
//  SyncToolbarButton.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One toolbar button for a remote command — Fetch, Pull, or Push — across every state it has.
///
/// It exists to hold one invariant that the three buttons cannot hold individually: **a remote
/// command's toolbar item keeps its structural identity for the command's whole life.** Each
/// button used to swap one `Button` for a different `Button` through an `if` / `else`, so starting
/// a command changed the view's identity. `ToolbarItemGroup` bridges to `NSToolbarItemGroup`, and
/// a child that cannot be updated in place is rebuilt — which took the rebuilt item out of the
/// group and split the toolbar apart at the moment the user was watching it for progress.
///
/// So there is exactly one `Button` here and it is never replaced. Everything that varies —
/// the action, the symbol, the count, the help, the accessibility identifier — is a *value* passed
/// in by the caller and updated in place. The `if` inside the label is safe because it is below
/// the toolbar item, not the toolbar item itself.
///
/// The identifiers still switch with the state, because `ColofaUITests` addresses the idle and
/// running states as different elements.
struct SyncToolbarButton: View {

    /// The symbol shown when no command is running. Replaced by a spinner while one is.
    let systemImage: String

    /// The count badged beside the symbol, or `nil` for no badge. Hidden while running: the
    /// spinner takes the symbol's place and the number is about to be recomputed by the reload
    /// anyway, so leaving it up would be showing a figure the command is in the middle of
    /// invalidating.
    let count: Int?

    /// What a count means to VoiceOver — `.ahead` for Push, `.behind` for Pull.
    let countLabel: LocalizedStringResource?

    let isRunning: Bool
    let isEnabled: Bool
    let help: String
    let accessibilityLabel: LocalizedStringResource
    let accessibilityIdentifier: String

    /// What the running command is doing, which is the value VoiceOver reports in that state.
    let progressDescription: String?

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LayoutMetrics.Toolbar.countSpacing) {
                // The symbol keeps its place while the spinner sits on top of it, so the button
                // does not change width — and therefore does not move its neighbours — when a
                // command starts.
                // The spinner is inserted rather than kept at zero opacity: a hidden
                // `ProgressView` keeps animating, and three of them idling in the toolbar of an
                // app opened dozens of times a day is a cost with nothing to show for it. The
                // branch is safe here for the same reason the count's is — it is inside the
                // button's label, not the toolbar item.
                ZStack {
                    Image(systemName: systemImage)
                        .opacity(isRunning ? 0 : 1)
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if let count, !isRunning {
                    Text(count, format: .number)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .help(help)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(verbatim: accessibilityValue))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// A count that exists only as a numeral beside an icon would be a fact living in the visual
    /// alone, which the project does not allow. It is spelled out here instead.
    private var accessibilityValue: String {
        if let progressDescription {
            return progressDescription
        }
        guard let count, let countLabel else {
            return ""
        }
        return "\(String(localized: countLabel)) \(count)"
    }
}
