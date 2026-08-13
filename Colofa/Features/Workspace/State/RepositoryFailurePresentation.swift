////
//  RepositoryFailurePresentation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

enum RepositoryFailurePresentation: Sendable {
    case repositoryOpenAlert(RepositoryOpenError)
    case mutationAlert(RepositoryOpenError, title: LocalizedStringResource)
    case details(GitFailureDetails, message: LocalizedStringResource)
}
