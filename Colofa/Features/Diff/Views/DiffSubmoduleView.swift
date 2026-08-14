////
//  DiffSubmoduleView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// A submodule change is a move between two Commits, so both are stated. A side is omitted when
/// the submodule was added or removed and that side genuinely has no Commit.
struct DiffSubmoduleView: View {
    let oldCommitID: String?
    let newCommitID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.contentSpacing) {
            Label(.diffSubmodule, systemImage: "shippingbox")
            if let oldCommitID {
                LabeledContent(String(localized: .diffOldCommit)) {
                    Text(verbatim: oldCommitID)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            if let newCommitID {
                LabeledContent(String(localized: .diffNewCommit)) {
                    Text(verbatim: newCommitID)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
