////
//  AuthenticationHostKeyDetails.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The host and fingerprint a new SSH host key has to be recognized by.
///
/// The fingerprint is shown exactly as OpenSSH read it, monospaced and selectable, because the
/// user compares it character by character against what their provider published. Nothing here
/// is abbreviated: a shortened fingerprint is a fingerprint that cannot be compared.
struct AuthenticationHostKeyDetails: View {
    let host: String?
    let fingerprint: String

    var body: some View {
        VStack(alignment: .leading) {
            if let host {
                LabeledContent(String(localized: .authenticationHost)) {
                    Text(verbatim: host)
                        .textSelection(.enabled)
                }
                .accessibilityIdentifier("repository.authentication.host")
            }

            LabeledContent(String(localized: .authenticationFingerprint)) {
                Text(verbatim: fingerprint)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("repository.authentication.fingerprint")
        }
    }
}
