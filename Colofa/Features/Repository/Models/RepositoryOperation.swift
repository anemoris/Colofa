////
//  RepositoryOperation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

enum RepositoryOperation: Equatable, Sendable {
    case am
    case cherryPick
    case merge
    case rebase
    case revert
}
