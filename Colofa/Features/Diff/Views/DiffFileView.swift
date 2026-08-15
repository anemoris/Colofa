////
//  DiffFileView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One file's patch: its header, then whatever Git actually had to say about it.
struct DiffFileView: View {
    let file: DiffFile
    let layout: DiffLayout

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                switch file.content {
                case .text(let hunks) where hunks.isEmpty:
                    DiffNoteView(
                        title: .diffNoTextualChanges,
                        message: .diffNoTextualChangesDescription,
                        systemImage: "text.append"
                    )
                case .text(let hunks):
                    ForEach(hunks) { hunk in
                        DiffHunkView(hunk: hunk, layout: layout)
                    }
                case .binary:
                    DiffNoteView(
                        title: .diffBinaryContent,
                        message: .diffBinaryContentDescription,
                        systemImage: "doc.badge.gearshape"
                    )
                case .submodule(let oldCommitID, let newCommitID):
                    DiffSubmoduleView(oldCommitID: oldCommitID, newCommitID: newCommitID)
                }
            } header: {
                DiffFileHeader(file: file)
            }
        }
    }
}
