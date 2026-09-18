////
//  StashDetailView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One selected Stash: what Git recorded about it, the paths it saved, and the read-only Diff of
/// whichever of those is chosen.
///
/// Nothing here stages, restores, or removes anything. A Stash is content Git holds outside the
/// working tree, so the patch has no Stage action beside it — there is no index for it to move to.
struct StashDetailView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        @Bindable var state = state

        if let stash = state.selectedStash {
            VStack(spacing: 0) {
                ScrollView {
                    StashSummaryView(stash: stash, detail: state.stashDetail)
                        .padding()
                }
                .frame(maxHeight: LayoutMetrics.Stash.maximumDetailHeight)
                .scrollIndicators(.hidden)

                Divider()

                if let files = state.stashDetail?.detail?.files {
                    StashChangedFilesView(files: files)
                    Divider()
                }

                DiffView(
                    layout: $state.diffLayout,
                    state: state.diff,
                    fileURL: nil,
                    loadAnyway: loadAnyway,
                    reload: reloadDiff
                )
            }
            // Read separately from the list, which deliberately leaves the saved paths unread:
            // counting them is a second command per entry.
            .task(id: state.stashDetailIdentity) {
                await state.loadStashDetail()
            }
        } else {
            ContentUnavailableView {
                Label(.noStashSelected, systemImage: "tray.full")
            } description: {
                Text(.noStashSelectedDescription)
            }
            .accessibilityIdentifier("repository.stashes.noStashSelected")
        }
    }

    private func loadAnyway() {
        Task {
            await state.loadDiffAnyway()
        }
    }

    private func reloadDiff() {
        Task {
            await state.loadDiff()
        }
    }
}

/// What Git recorded about the entry: its own description, where it is addressed, and who saved
/// it when.
private struct StashSummaryView: View {
    let stash: Stash
    let detail: StashDetailLoadState?

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.sectionSpacing) {
            VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
                // Git's own words for the entry, including the `On <branch>:` it wrote itself.
                Text(verbatim: stash.message)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("repository.stash.message")

                switch detail {
                case .loading:
                    // The saved paths and the Diff below both wait on this read, so without it
                    // the pane would sit blank with nothing saying anything is on its way.
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityIdentifier("repository.stash.loading")
                case .failed(let error):
                    Text(error.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("repository.stash.failure")
                case .loaded, nil:
                    EmptyView()
                }
            }

            StashIdentityView(stash: stash)
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StashIdentityView: View {
    let stash: Stash

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
            LabeledContent(String(localized: .stashSelector)) {
                Text(verbatim: stash.selector)
                    .font(.system(.caption, design: .monospaced))
                    .accessibilityIdentifier("repository.stash.selector")
            }

            LabeledContent(String(localized: .commitObjectID)) {
                Text(verbatim: stash.objectID)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("repository.stash.objectID")
            }

            LabeledContent(String(localized: .commitAuthor)) {
                Text(verbatim: "\(stash.authorName) <\(stash.authorEmail)>")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("repository.stash.author")
            }

            LabeledContent(String(localized: .stashSaved)) {
                Text(
                    stash.authoredDate,
                    format: .dateTime.year().month().day().hour().minute().second()
                )
                .accessibilityIdentifier("repository.stash.date")
            }

            // Named after the option on the sheet rather than described some other way: this is
            // the answer to the question that was asked when the Stash was saved, and Git records
            // it in the entry itself rather than anywhere Colofa had to remember.
            LabeledContent(String(localized: .includeUntrackedFiles)) {
                Text(stash.includesUntrackedFiles ? .yes : .no)
                    .accessibilityIdentifier("repository.stash.untracked")
            }
        }
    }
}

/// The paths the Stash saved, one of which the Diff below is reading.
///
/// Selecting one is what asks Git for that file's patch, so a Stash is read a file at a time —
/// the same way a Commit is, and for the same reason: a size limit is then reached by a file
/// rather than by everything that was saved at once.
private struct StashChangedFilesView: View {
    @Environment(WorkspaceState.self) private var state
    let files: [StashFile]

    var body: some View {
        @Bindable var state = state

        VStack(alignment: .leading, spacing: 0) {
            LabeledContent(String(localized: .diffChangedFiles)) {
                Text(files.count, format: .number)
            }
            .font(.callout)
            .padding(.horizontal)
            .padding(.vertical, LayoutMetrics.Diff.bandVerticalPadding)

            if files.isEmpty {
                Text(.diffNoTextualChanges)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, LayoutMetrics.Diff.bandVerticalPadding)
            } else {
                List(selection: $state.selectedStashFileID) {
                    ForEach(files) { file in
                        StashFileRow(file: file)
                            .tag(file.id)
                    }
                }
                .listStyle(.inset)
                .frame(maxHeight: LayoutMetrics.Stash.maximumChangedFilesHeight)
            }
        }
        .accessibilityIdentifier("repository.stash.changedFiles")
    }
}

private struct StashFileRow: View {
    let file: StashFile

    var body: some View {
        DiffPathLabel(
            path: file.summary.newPath,
            originalPath: file.summary.isRenamed ? file.summary.oldPath : nil
        ) {
            if file.isUntracked {
                // Said in words rather than shown by position: a path Git was not tracking when
                // the Stash was saved is compared against nothing, so its patch is every line of
                // it — which would otherwise read as a file that was rewritten wholesale.
                Text(.stashUntrackedFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let stats = file.summary.stats {
                DiffStatsLabel(stats: stats)
            } else {
                Text(.diffBinaryContent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repository.stash.file.\(file.summary.newPath)")
    }
}
