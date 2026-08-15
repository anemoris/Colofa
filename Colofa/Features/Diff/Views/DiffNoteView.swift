////
//  DiffNoteView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// What Colofa says instead of lines, for a change that has none to show.
struct DiffNoteView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    var body: some View {
        HStack(alignment: .top) {
            Label {
                VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
                    Text(title)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}
