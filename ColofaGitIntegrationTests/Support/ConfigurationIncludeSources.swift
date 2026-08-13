////
//  ConfigurationIncludeSources.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// The include files a configuration fixture wrote, so assertions can name the origin each
/// value is expected to come from.
struct ConfigurationIncludeSources {
    /// Pulled in from the global file by a plain `include.path`.
    let global: URL
    /// Pulled in by an `includeIf.gitdir:` conditional include.
    let conditional: URL
    /// Pulled in from the repository's own config by `include.path`.
    let local: URL
}
