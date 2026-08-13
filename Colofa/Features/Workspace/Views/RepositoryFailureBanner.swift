////
//  RepositoryFailureBanner.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryFailureBanner: View {
    @Environment(WorkspaceState.self) private var state
    @State private var isExpanded = true
    let details: GitFailureDetails
    let message: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            DisclosureGroup(isExpanded: $isExpanded) {
                LabeledContent(String(localized: .command)) {
                    Text(details.command)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                if !details.output.isEmpty {
                    LabeledContent(String(localized: .output)) {
                        ScrollView {
                            Text(details.output)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: LayoutMetrics.maximumFailureDetailsHeight)
                    }
                }
            } label: {
                Text(message)
            }

            Button(.dismiss, systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
        }
        .padding()
        .background(.bar)
        .accessibilityIdentifier("repository.failureBanner")
    }

    private func dismiss() {
        state.dismissFailureDetails()
    }
}
