////
//  GitConfigurationRelationship.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

enum GitConfigurationRelationship: Equatable, Sendable {
    case shadowedBy(
        GitConfigurationEntry,
        removableScope: GitConfigurationEditScope?
    )
    case overridesGlobal(GitConfigurationEntry)
    case inheritsGlobal(GitConfigurationEntry)

    var entry: GitConfigurationEntry {
        switch self {
        case .shadowedBy(let entry, _), .overridesGlobal(let entry), .inheritsGlobal(let entry):
            entry
        }
    }

    var removableScope: GitConfigurationEditScope? {
        switch self {
        case .shadowedBy(_, let removableScope):
            removableScope
        case .overridesGlobal:
            .repository
        case .inheritsGlobal:
            nil
        }
    }
}
