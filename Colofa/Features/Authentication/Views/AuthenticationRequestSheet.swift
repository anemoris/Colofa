////
//  AuthenticationRequestSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The question Git or OpenSSH is asking right now, asked natively.
///
/// It appears only while a command is waiting for it and goes away the moment it is answered or
/// cancelled. Cancelling stops the command rather than leaving it blocked on an answer that will
/// never come.
struct AuthenticationRequestSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let request = state.authenticationRequest {
            AuthenticationRequestForm(request: request)
        }
    }
}

private struct AuthenticationRequestForm: View {
    @Environment(WorkspaceState.self) private var state
    let request: AuthenticationRequest
    @FocusState private var isAnswerFocused: Bool

    var body: some View {
        @Bindable var state = state

        VStack(alignment: .leading) {
            Text(request.kind.title)
                .font(.headline)

            Text(request.kind.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let fingerprint = request.fingerprint {
                AuthenticationHostKeyDetails(host: request.subject, fingerprint: fingerprint)
            } else {
                if let subject = request.subject {
                    LabeledContent(String(localized: request.kind.subjectLabel)) {
                        Text(verbatim: subject)
                            .textSelection(.enabled)
                    }
                    .accessibilityIdentifier("repository.authentication.subject")
                }
                AuthenticationAnswerField(
                    kind: request.kind,
                    answer: $state.authenticationAnswer,
                    isFocused: $isAnswerFocused,
                    submit: state.submitAuthentication
                )
            }

            // Colofa's own words explain every question it recognizes. One it does not is shown
            // exactly as it arrived, because guessing at it is what would be misleading — but
            // inside a height it cannot grow past, because how long it is was decided by whoever
            // asked it rather than by Colofa.
            if request.kind == .unrecognized {
                AuthenticationPromptText(prompt: request.prompt)
            }

            Text(.authenticationEphemeralNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelAuthentication)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repository.authentication.cancel")
                Button(request.kind.submitTitle, action: state.submitAuthentication)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canSubmitAuthentication)
                    .accessibilityIdentifier("repository.authentication.confirm")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Authentication.dialogWidth)
    }
}

/// A question Colofa could not classify, shown as it arrived and no taller than the sheet can
/// afford.
private struct AuthenticationPromptText: View {
    let prompt: String

    var body: some View {
        ScrollView {
            Text(verbatim: prompt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("repository.authentication.prompt")
        }
        .frame(maxHeight: LayoutMetrics.Authentication.promptMaxHeight)
    }
}
