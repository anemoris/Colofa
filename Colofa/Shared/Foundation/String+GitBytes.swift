////
//  String+GitBytes.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

extension String {
    /// Git writes UTF-8. Anything else is still shown rather than dropped: ISO Latin-1 maps every
    /// byte, so a Repository holding content in another encoding stays readable and diagnosable
    /// instead of coming back empty.
    nonisolated init(gitBytes: some Collection<UInt8>) {
        self = String(bytes: gitBytes, encoding: .utf8)
            ?? String(bytes: gitBytes, encoding: .isoLatin1)
            ?? ""
    }
}
