////
//  RepositoryConfigurationNote.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import SwiftUI

/// The one-line notes shown under a configuration field: format warnings and scope
/// relationships.
///
/// Both call sites render the same way, so the caption styling and the warning colour live here
/// instead of being repeated as literals. A warning is never signalled by colour alone — the
/// caller always pairs it with a distinct SF Symbol.
struct RepositoryConfigurationNote: View {
    let message: LocalizedStringResource
    let systemImage: String
    let isWarning: Bool

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(isWarning ? Color.orange : Color.secondary)
    }
}
