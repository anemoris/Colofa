////
//  DiffLimitsTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct DiffLimitsTests {
    private let limits = DiffLimits.standard

    @Test
    func standardLimitsAreTwoMebibytesAndTenMebibytes() {
        #expect(limits.automaticByteCount == 2_097_152)
        #expect(limits.automaticLineCount == 20_000)
        #expect(limits.hardByteCount == 10_485_760)
        #expect(limits.hardLineCount == 100_000)
    }

    /// These are the values a read actually stops at, so the boundary suite in
    /// `GitBoundedReaderTests` is testing the same numbers this states.
    @Test
    func boundsCarryTheLimitsAReadStopsAt() {
        #expect(
            limits.automaticBounds
                == GitOutputBounds(byteCount: 2_097_152, lineCount: 20_000)
        )
        #expect(
            limits.hardBounds == GitOutputBounds(byteCount: 10_485_760, lineCount: 100_000)
        )
    }
}
