////
//  DiffMeasurementLabel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// How large a patch was found to be.
///
/// A measurement that stopped at a limit is reported as a floor rather than a figure, because
/// Colofa deliberately never read the rest and does not know the total.
struct DiffMeasurementLabel: View {
    let measurement: DiffMeasurement

    var body: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: LayoutMetrics.Diff.sectionSpacing,
            verticalSpacing: LayoutMetrics.Diff.captionSpacing
        ) {
            GridRow {
                Text(.diffSize)
                    .foregroundStyle(.secondary)
                // The binary style, because the limits themselves are mebibytes: a decimal
                // "10.49 MB" would disagree with the 10 MiB it stopped at.
                bounded(Int64(measurement.byteCount).formatted(.byteCount(style: .memory)))
            }
            GridRow {
                Text(.diffLines)
                    .foregroundStyle(.secondary)
                bounded(measurement.lineCount.formatted(.number))
            }
        }
        .font(.callout)
    }

    private func bounded(_ value: String) -> Text {
        measurement.isComplete ? Text(verbatim: value) : Text(.diffMoreThan(value))
    }
}
