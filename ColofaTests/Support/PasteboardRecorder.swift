////
//  PasteboardRecorder.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// A pasteboard that keeps what was copied instead of writing it to the machine running the
/// tests, which is the only part of a Copy action worth asserting.
@MainActor
final class PasteboardRecorder {
    private(set) var written: [String] = []

    var writer: PasteboardWriter {
        PasteboardWriter { [self] text in
            written.append(text)
        }
    }
}
