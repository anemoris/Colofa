////
//  DiffLayout.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

nonisolated enum DiffLayout: String, CaseIterable, Identifiable, Sendable {
    case unified
    case split

    var id: String { rawValue }

    var name: LocalizedStringResource {
        switch self {
        case .unified: .unifiedLayout
        case .split: .splitLayout
        }
    }
}
