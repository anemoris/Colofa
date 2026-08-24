////
//  AuthenticationAnswerField.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Where an Authentication Request is answered.
///
/// A secret is entered in a secure field and everything else in an ordinary one, decided by the
/// question rather than by the view: a username is not hidden while it is typed, and a passphrase
/// always is.
struct AuthenticationAnswerField: View {
    let kind: AuthenticationRequestKind
    @Binding var answer: String
    @FocusState.Binding var isFocused: Bool
    let submit: () -> Void

    var body: some View {
        Group {
            if kind.isSecret {
                SecureField(String(localized: kind.fieldLabel), text: $answer)
            } else {
                TextField(String(localized: kind.fieldLabel), text: $answer)
            }
        }
        .textFieldStyle(.roundedBorder)
        .focused($isFocused)
        // The prompt exists to be filled in, so it opens where it is filled in. A question with
        // nothing to type — a host key to recognize — has no field and leaves focus on the
        // buttons instead.
        .defaultFocus($isFocused, true)
        .onSubmit(submit)
        .accessibilityLabel(Text(kind.fieldLabel))
        .accessibilityIdentifier("repository.authentication.answer")
    }
}
