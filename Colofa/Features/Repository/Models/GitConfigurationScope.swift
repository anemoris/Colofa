////
//  GitConfigurationScope.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

nonisolated enum GitConfigurationScope: Equatable, Hashable, Sendable {
    case system
    case global
    case local
    case worktree
    case command
    case unknown(String)

    nonisolated init(rawValue: String) {
        switch rawValue {
        case "system":
            self = .system
        case "global":
            self = .global
        case "local":
            self = .local
        case "worktree":
            self = .worktree
        case "command":
            self = .command
        default:
            self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .system:
            "system"
        case .global:
            "global"
        case .local:
            "local"
        case .worktree:
            "worktree"
        case .command:
            "command"
        case .unknown(let value):
            value
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .system:
            .configurationSystemScope
        case .global:
            .configurationGlobalScope
        case .local:
            .configurationRepositoryScope
        case .worktree:
            .configurationWorktreeScope
        case .command:
            .configurationCommandScope
        case .unknown:
            .configurationUnknownScope
        }
    }

    var precedenceRank: Int? {
        switch self {
        case .system:
            0
        case .global:
            1
        case .local:
            2
        case .worktree:
            3
        case .command:
            4
        case .unknown:
            nil
        }
    }
}
