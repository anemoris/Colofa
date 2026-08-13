////
//  GitConfigurationEditScope.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

nonisolated enum GitConfigurationEditScope: String, CaseIterable, Hashable, Identifiable, Sendable {
    case repository
    case global

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .repository:
            .configurationRepositoryScope
        case .global:
            .configurationGlobalScope
        }
    }

    var destinationDescription: LocalizedStringResource {
        switch self {
        case .repository:
            .configurationRepositoryDestination
        case .global:
            .configurationGlobalDestination
        }
    }

    var gitArguments: [String] {
        switch self {
        case .repository:
            ["--local"]
        case .global:
            ["--global"]
        }
    }

    var gitScope: GitConfigurationScope {
        switch self {
        case .repository:
            .local
        case .global:
            .global
        }
    }
}
