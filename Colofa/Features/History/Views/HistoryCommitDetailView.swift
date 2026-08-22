////
//  HistoryCommitDetailView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One selected Commit: what it says, who wrote it and when, where it sits in History, and the
/// read-only Diff it introduced.
struct HistoryCommitDetailView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        @Bindable var state = state

        if let commit = state.selectedCommit {
            VStack(spacing: 0) {
                ScrollView {
                    HistoryCommitSummaryView(commit: commit, detail: state.commitDetail)
                        .padding()
                }
                .frame(maxHeight: LayoutMetrics.History.maximumDetailHeight)
                .scrollIndicators(.hidden)

                HistoryCommitBranchButton(commit: commit)

                Divider()

                if let files = state.commitDetail?.detail?.changedFiles {
                    HistoryCommitChangedFilesView(files: files)
                    Divider()
                }

                DiffView(
                    layout: $state.diffLayout,
                    state: state.diff,
                    fileURL: state.diffFileURL,
                    loadAnyway: loadAnyway,
                    reload: reloadDiff
                )
            }
            // Read separately from the page, which deliberately leaves a Commit's message and
            // changed paths unread: a page holds two hundred of them and neither has a bound.
            .task(id: state.commitDetailIdentity) {
                await state.loadCommitDetail()
            }
        } else {
            ContentUnavailableView {
                Label(.noCommitSelected, systemImage: "clock")
            } description: {
                Text(.noCommitSelectedDescription)
            }
            .accessibilityIdentifier("repository.history.noCommitSelected")
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

private struct HistoryCommitSummaryView: View {
    let commit: HistoryCommit
    let detail: CommitDetailLoadState?

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.sectionSpacing) {
            HistoryCommitMessageView(commit: commit, detail: detail)
            HistoryCommitIdentityView(commit: commit)
            HistoryCommitOriginView(commit: commit)
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The message as the Commit holds it, once it has been read. The row's Summary stands in until
/// then, so the pane never sits empty while the rest of the message is on its way.
private struct HistoryCommitMessageView: View {
    let commit: HistoryCommit
    let detail: CommitDetailLoadState?

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
            Text(verbatim: detail?.detail?.summary ?? commit.summary)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("repository.commit.summary")

            switch detail {
            case .loaded(let detail) where !detail.body.isEmpty:
                Text(verbatim: detail.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("repository.commit.body")
            case .failed(let error):
                Text(error.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("repository.commit.failure")
            case .loading:
                ProgressView()
                    .controlSize(.small)
            case .loaded, nil:
                EmptyView()
            }
        }
    }
}

/// Create Branch Here, as a visible control rather than only a right-click.
///
/// It opens the New Branch dialog on this Commit; the branch is created only once that dialog is
/// confirmed, so reading History still never changes the Repository on its own.
///
/// Its own band below the scrolling metadata rather than the last row inside it, for the reason
/// the changed paths sit outside too: a Commit message has no upper bound, and a control the user
/// has to scroll a bounded region to reach is not a visible one.
private struct HistoryCommitBranchButton: View {
    @Environment(WorkspaceState.self) private var state
    let commit: HistoryCommit

    var body: some View {
        Button(.createBranchHere, systemImage: "arrow.triangle.branch", action: createBranch)
            .disabled(!state.canBeginCreatingBranch)
            .help(
                String(
                    localized: state.branchCreationUnavailabilityReason?.message
                        ?? .createBranchHereHelp
                )
            )
            .accessibilityIdentifier("repository.commit.createBranch")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, LayoutMetrics.Diff.bandVerticalPadding)
    }

    private func createBranch() {
        state.beginCreatingBranch(at: commit)
    }
}

private struct HistoryCommitIdentityView: View {
    @Environment(WorkspaceState.self) private var state
    let commit: HistoryCommit

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
            LabeledContent(String(localized: .commitObjectID)) {
                HStack {
                    Text(verbatim: commit.objectID)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("repository.commit.objectID")
                    Button(.copySHA, systemImage: "doc.on.doc", action: state.copyCommitObjectID)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("repository.commit.copySHA")
                }
            }

            HistoryCommitPersonView(
                title: .commitAuthor,
                name: commit.authorName,
                email: commit.authorEmail,
                date: commit.authoredDate,
                dateTitle: .commitAuthored,
                identifier: "author"
            )
            HistoryCommitPersonView(
                title: .commitCommitter,
                name: commit.committerName,
                email: commit.committerEmail,
                date: commit.committedDate,
                dateTitle: .commitCommitted,
                identifier: "committer"
            )
        }
    }
}

private struct HistoryCommitPersonView: View {
    let title: LocalizedStringResource
    let name: String
    let email: String
    let date: Date
    let dateTitle: LocalizedStringResource
    let identifier: String

    var body: some View {
        LabeledContent(String(localized: title)) {
            Text(verbatim: "\(name) <\(email)>")
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("repository.commit.\(identifier)")
        }
        LabeledContent(String(localized: dateTitle)) {
            Text(date, format: .dateTime.year().month().day().hour().minute().second())
                .accessibilityIdentifier("repository.commit.\(identifier)Date")
        }
    }
}

/// Where the Commit sits: what it follows, and which Refs point at it.
private struct HistoryCommitOriginView: View {
    let commit: HistoryCommit

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
            LabeledContent(String(localized: .commitParents)) {
                HistoryCommitParentsView(commit: commit)
            }
            if !commit.refLabels.isEmpty {
                LabeledContent(String(localized: .commitRefs)) {
                    HistoryRefLabelsView(labels: commit.refLabels)
                }
            }
        }
    }
}

/// What Git reports as this Commit's parents, including when it reports none.
///
/// No parent means one of two different facts, and they are not interchangeable: the Repository
/// starts here, or the clone does. Git says which by marking a shallow boundary as grafted.
private struct HistoryCommitParentsView: View {
    let commit: HistoryCommit

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
            ForEach(commit.parentObjectIDs, id: \.self) { parent in
                Text(verbatim: parent)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if commit.isShallowBoundary {
                Text(.commitShallowBoundary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("repository.commit.shallowBoundary")
            } else if commit.isRoot {
                Text(.commitRoot)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("repository.commit.root")
            }
        }
        .accessibilityIdentifier("repository.commit.parents")
    }
}

/// The paths the Commit touched, one of which the Diff below is reading.
///
/// Its own region above the Diff rather than a block inside the scrolling metadata: choosing a
/// path is what this pane is for, and a Commit message has no upper bound to sit under. Selecting
/// one is what asks Git for that file's patch, so the Commit is read a file at a time — the same
/// way a working-tree Change is.
private struct HistoryCommitChangedFilesView: View {
    @Environment(WorkspaceState.self) private var state
    let files: [DiffFileSummary]

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
                List(selection: $state.selectedCommitFileID) {
                    ForEach(files) { file in
                        HistoryCommitFileRow(file: file)
                            .tag(file.id)
                    }
                }
                .listStyle(.inset)
                .frame(maxHeight: LayoutMetrics.History.maximumChangedFilesHeight)
            }
        }
        .accessibilityIdentifier("repository.commit.changedFiles")
    }
}

private struct HistoryCommitFileRow: View {
    let file: DiffFileSummary

    var body: some View {
        DiffPathLabel(
            path: file.newPath,
            originalPath: file.isRenamed ? file.oldPath : nil
        ) {
            if let stats = file.stats {
                DiffStatsLabel(stats: stats)
            } else {
                Text(.diffBinaryContent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repository.commit.file.\(file.newPath)")
    }
}
