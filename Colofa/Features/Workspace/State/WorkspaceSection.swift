////
//  WorkspaceSection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable, Sendable {
    case changes
    case history
    case stashes

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .changes: .changes
        case .history: .history
        case .stashes: .stashes
        }
    }

    var systemImage: String {
        switch self {
        case .changes: "arrow.triangle.2.circlepath"
        case .history: "clock"
        case .stashes: "tray.full"
        }
    }

    var emptyTitle: LocalizedStringResource {
        switch self {
        case .changes: .noChanges
        case .history: .noHistory
        case .stashes: .noStashes
        }
    }

    var emptyDescription: LocalizedStringResource {
        switch self {
        case .changes: .noChangesDescription
        case .history: .noHistoryDescription
        case .stashes: .noStashesDescription
        }
    }

    var accessibilityIdentifier: String {
        "baseline.section.\(rawValue)"
    }

    var emptyAccessibilityIdentifier: String {
        "baseline.empty.\(rawValue)"
    }
}
