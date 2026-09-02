////
//  UITestingFileSystemActions.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The file system a UI test sees.
///
/// It is the Repository stub, because the two cannot disagree: a Move to Trash the stub accepts
/// has to be a row the stub then stops reporting. It also means no UI test ever puts a file into
/// the Trash of the machine running it, or takes Finder to the foreground in the middle of one.
extension FileSystemActions {
    static func uiTesting(_ backend: UITestingRepositoryService) -> Self {
        Self(
            moveToTrash: { url in
                try await backend.moveToTrash(url)
            },
            reveal: { url in
                await backend.reveal(url)
            }
        )
    }
}
#endif
