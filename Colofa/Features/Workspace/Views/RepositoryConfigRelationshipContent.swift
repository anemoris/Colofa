////
//  RepositoryConfigRelationshipContent.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

struct RepositoryConfigRelationshipContent {
    let message: LocalizedStringResource
    let removalTitle: LocalizedStringResource?
    let systemImage: String
    let isWarning: Bool

    init(relationship: GitConfigurationRelationship) {
        switch relationship {
        case .shadowedBy(let entry, let removableScope):
            message = if entry.scope == .local {
                .configurationRepositoryShadowsValue(entry.value)
            } else {
                .configurationSourceShadowsValue(entry.value)
            }
            removalTitle = removableScope == nil
                ? nil
                : .configurationRemoveRepositoryOverride
            systemImage = "exclamationmark.triangle"
            isWarning = true
        case .overridesGlobal(let entry):
            message = .configurationOverridesGlobalValue(entry.value)
            removalTitle = .configurationRemoveOverride
            systemImage = "arrow.turn.down.right"
            isWarning = false
        case .inheritsGlobal(let entry):
            message = .configurationInheritsGlobalValue(entry.value)
            removalTitle = nil
            systemImage = "arrow.turn.down.right"
            isWarning = false
        }
    }
}
