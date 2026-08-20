////
//  UITestingCommitID.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
/// How a UI-testing Commit's object ID is spelled.
///
/// Compiled into both the app and the UI test target, so the fixture and the test that looks for
/// one of its rows cannot drift apart on what a Commit is called.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingHistory` builds these from an actor.
nonisolated enum UITestingCommitID {
    static let mainPrefix = "m"
    static let branchPrefix = "b"
    static let remotePrefix = "r"
    static let tagPrefix = "t"

    /// A fixed-width object ID, so no two indexes can pad into the same forty characters.
    static func objectID(prefix: String = mainPrefix, index: Int) -> String {
        let digits = String(index)
        let seed = prefix + String(repeating: "0", count: 6 - digits.count) + digits
        return seed + String(repeating: "0", count: 40 - seed.count)
    }

    static func rowIdentifier(prefix: String = mainPrefix, index: Int) -> String {
        "repository.history.commit.\(objectID(prefix: prefix, index: index))"
    }
}
#endif
