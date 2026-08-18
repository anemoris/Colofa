////
//  HistoryReferenceLabel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Names the Ref whose History is on screen.
///
/// HEAD names whatever it currently points at, which is a branch, an Unborn Branch, or a Commit,
/// so it is shown through the same label the sidebar uses rather than as the word `HEAD`.
struct HistoryReferenceLabel: View {
    let reference: GitReference
    let head: RepositoryHead?

    var body: some View {
        switch reference {
        case .head:
            if let head {
                RepositoryHeadLabel(head: head)
            } else {
                Label(.head, systemImage: "location")
            }
        case .localBranch(let name):
            HistoryNamedReferenceLabel(
                name: name,
                systemImage: "arrow.triangle.branch",
                kind: .historyRefLocalBranch
            )
        case .remoteBranch(let name):
            HistoryNamedReferenceLabel(
                name: name,
                systemImage: "arrow.triangle.branch",
                kind: .historyRefRemoteBranch
            )
        case .tag(let name):
            HistoryNamedReferenceLabel(name: name, systemImage: "tag", kind: .historyRefTag)
        }
    }
}

private struct HistoryNamedReferenceLabel: View {
    let name: String
    let systemImage: String
    /// What kind of Ref this is, spelled out so the icon is never the only thing that says it.
    let kind: LocalizedStringResource

    var body: some View {
        Label {
            Text(verbatim: name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: systemImage)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(kind))
        .accessibilityValue(Text(verbatim: name))
    }
}
