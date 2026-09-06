////
//  WorkspaceState.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceState {
    var isPresentingRepositoryPicker = false
    var isShowingInspector = false
    var configurationEditingScope = GitConfigurationEditScope.repository
    var selectedChange: RepositoryChangeSelection?
    var commitDraft = CommitMessageDraft()
    var isConfirmingHistoryRewrite = false
    var isShowingStaleAmendAlert = false

    /// Set when a reload closed a Push or Publish dialog because what it showed had stopped being
    /// true. The dialog goes on its own; this is what stops it from going without explanation.
    var isShowingStalePushAlert = false

    /// The open New Branch dialog, or `nil` when none is. Not private: the Branches extension in
    /// WorkspaceState+Branches.swift owns it, and Swift keeps `private` within one file.
    var branchCreation: BranchCreationDraft?

    /// The local Branch waiting for the confirmation that removes it, or `nil` when none is. Not
    /// private: the deletion extension in WorkspaceState+BranchDeletion.swift owns it, and Swift
    /// keeps `private` within one file. Nothing has run while it is set.
    var branchDeletion: BranchDeletion?

    /// Set when a reload closed a Delete Branch confirmation because the Branch it named had
    /// stopped being there. The dialog goes on its own; this is what stops it from going without
    /// explanation.
    var isShowingStaleBranchDeletionAlert = false

    /// The open Merge confirmation, or `nil` when none is, owned by WorkspaceState+Merge.swift.
    var mergeDraft: MergeDraft?

    /// The destructive file action waiting for its confirmation, or `nil` when none is. Not
    /// private: the file-actions extension in WorkspaceState+FileActions.swift owns it, and Swift
    /// keeps `private` within one file. Nothing has run while it is set.
    var pendingFileAction: DestructiveFileAction?

    // Not private: the Fetch extension in WorkspaceState+Fetch.swift owns everything below, and
    // Swift keeps `private` within one file. Nothing else writes to them.

    /// The Fetch running right now, or `nil` when none is. Its presence is what turns the
    /// toolbar's Fetch into the Cancel that stops it.
    var fetchProgress: FetchProgress?

    /// The open Fetch Tags dialog, or `nil` when none is.
    var tagFetchSelection: TagFetchSelection?

    /// The running Fetch's own task, which is what Cancel cancels. Unlike a mutation, a command
    /// that contacts a remote has no duration Colofa can promise, so it stays interruptible.
    ///
    /// It covers the whole of what talks to the remote, including the second read that explains
    /// a refused Fetch Tags, so nothing outlives the Cancel that stops it.
    var fetchTask: Task<FetchReport, Never>?

    // Not private: the Pull extension in WorkspaceState+Pull.swift owns both of these, and Swift
    // keeps `private` within one file. `pullProgress` is what turns the toolbar's Pull into the
    // Cancel that stops it, and `pullTask` is what that Cancel cancels — both halves of the Pull,
    // though only the first is ever offered as cancellable.
    var pullProgress: PullProgress?
    var pullTask: Task<PullOutcome, Never>?

    // Not private: the Push extension in WorkspaceState+Push.swift owns the three below, and Swift
    // keeps `private` within one file. `pushProgress` is what turns the toolbar's Push into the
    // Cancel that stops it, `pushTask` is what that Cancel cancels, and `pushDialog` is whichever
    // question a Push had to ask before anything left for a remote.
    var pushProgress: PushProgress?
    var pushTask: Task<PushOutcome, Never>?
    var pushDialog: PushDialog?

    // Not private: the authentication extension in WorkspaceState+Authentication.swift owns the
    // three below, and Swift keeps `private` within one file. Nothing else writes to them.

    /// The Authentication Request on screen, or `nil` when nothing is asking. It exists only
    /// while the command that asked is waiting for it, and nothing about it is written anywhere.
    var authenticationRequest: AuthenticationRequest?

    /// What has been typed into the open Authentication Request, held for exactly as long as the
    /// field is on screen and cleared in the same step that hands it over.
    var authenticationAnswer = ""

    /// The command waiting for an answer, resumed exactly once. Excluded from observation: it is
    /// how the answer travels, not something a view reads.
    @ObservationIgnored
    var pendingAuthentication: CheckedContinuation<AuthenticationResponse, Never>?

    /// When Colofa last fetched the open Repository, or `nil` when it never has.
    ///
    /// App-owned metadata: Git records no such time, so this is Colofa's own answer about
    /// Colofa's own work rather than something read out of the Repository.
    var lastFetchDate: Date?

    // Not private: the History extension in WorkspaceState+History.swift owns both of these, and
    // Swift keeps `private` within one file. Nothing else writes to them.
    var storedSidebarSelection = SidebarSelection.section(.changes)
    var historyPresentation = HistoryPresentation()

    /// Which layout the Diff pane uses, and which walk History reads. Deliberately not
    /// persisted, and deliberately outside `historyPresentation`: both are how the user wants to
    /// read this session rather than state belonging to a Repository or a Ref.
    var diffLayout = DiffLayout.unified
    var historyScope = HistoryScope.reachable

    // Not private: the Diff extension in WorkspaceState+Diff.swift owns everything below, and
    // Swift keeps `private` within one file. Nothing else writes to them.
    var diff: DiffLoadState?
    var diffFileURL: URL?
    var diffLoadID = 0
    var loadedDiffKey: DiffKey?
    var loadedDiffKind: RepositoryChangeKind?
    var confirmedDiffKey: DiffKey?

    /// Counts authoritative Repository reads. A Diff is a view of content Colofa did not read
    /// with the snapshot, so every reload has to re-ask rather than assume the patch still holds.
    private(set) var repositoryGeneration = 0

    private(set) var repository: RepositorySnapshot?

    /// Not private: the failure extension in WorkspaceState+Failures.swift owns presenting and
    /// dismissing this, and Swift keeps `private` within one file. Nothing else writes to it.
    var repositoryFailure: RepositoryFailurePresentation?

    private(set) var isLoadingRepository = false
    /// Not private: the mutation extension in WorkspaceState+Mutations.swift is what sets it,
    /// and Swift keeps `private` within one file. Nothing else writes to it.
    var isPerformingMutation = false
    private(set) var gitAvailability: GitAvailability?

    /// `UserDefaults` key holding the most recently opened Repository path. UI tests seed it
    /// by passing `-lastRepositoryPath <path>` as a launch argument.
    private static let lastRepositoryPathKey = "lastRepositoryPath"

    // Not private: the Diff extension reads patches through it directly, because a Diff is not
    // published Repository state and does not travel with a snapshot.
    let repositoryService: RepositoryService
    let pasteboard: PasteboardWriter

    /// Not private: the file-actions extension in WorkspaceState+FileActions.swift reaches the
    /// Trash and Finder through it, and Swift keeps `private` within one file.
    let fileSystem: FileSystemActions

    /// Not private: the Fetch extension persists the app-owned last-Fetch time through it, and
    /// Swift keeps `private` within one file.
    let userDefaults: UserDefaults
    private let launchArguments: [String]
    private var hasStarted = false
    private var repositoryLoadID = 0
    private var activeReplacementLoadID: Int?

    /// Set while an Amend Colofa itself is running, which is the one time HEAD is expected to
    /// move. Any reload publishing during that window reports Colofa's own rewrite, whichever
    /// task started it, so none of them may declare the Amend draft stale.
    ///
    /// Not private for the same reason as `isPerformingMutation`: the mutation extension in
    /// WorkspaceState+Mutations.swift is what sets it.
    var isRewritingHead = false

    /// Set while a Commit Colofa started owns the message. Git was handed exactly what the
    /// composer held when the command began, and the composer is cleared once it succeeds, so
    /// text typed in between would neither reach that Commit nor survive the clear. The composer
    /// stops accepting text for that window rather than accepting text it would then discard.
    ///
    /// Deliberately narrower than `canMutateRepository`: a Fetch, a Pull, or a Staging command
    /// leaves the message alone, and writing one while any of those runs is ordinary work.
    ///
    /// Not private for the same reason as `isPerformingMutation`: the Commit extension in
    /// WorkspaceState+Commit.swift is what sets it.
    var isCommitting = false

    init(
        repositoryService: RepositoryService = .live(),
        pasteboard: PasteboardWriter = .live(),
        fileSystem: FileSystemActions = .live(),
        userDefaults: UserDefaults = .standard,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.repositoryService = repositoryService
        self.pasteboard = pasteboard
        self.fileSystem = fileSystem
        self.userDefaults = userDefaults
        self.launchArguments = launchArguments
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        let availability = await repositoryService.availability()
        gitAvailability = availability
        guard case .available = availability else {
            return
        }

        if isUITesting,
           !launchArguments.contains("-\(Self.lastRepositoryPathKey)") {
            return
        }

        guard let savedURL = savedRepositoryURL() else {
            if !isUITesting {
                isPresentingRepositoryPicker = true
            }
            return
        }

        let restored = await openRepository(
            at: savedURL,
            presentsFailure: false
        )
        if !restored {
            clearSavedRepository()
            isPresentingRepositoryPicker = true
        }
    }

    /// A panel opened while nothing was running can still be sitting there once a Fetch or a
    /// Pull starts, so the gate that disables Open Repository is checked again on the way back.
    func handleRepositorySelection(_ result: Result<URL, any Error>) async {
        guard canReplaceRepository else {
            return
        }
        switch result {
        case .success(let url):
            await openRepository(at: url, isReplacement: true)
        case .failure(let error):
            guard (error as? CocoaError)?.code != .userCancelled else {
                return
            }
            presentRepositoryOpenError(.locationUnavailable)
        }
    }

    func refresh() async {
        guard let repository, activeReplacementLoadID == nil else {
            return
        }
        _ = await openRepository(at: repository.rootURL, presentsFailure: true)
    }

    var canReplaceRepository: Bool {
        !isPerformingMutation && !isFetching && !isPulling && !isPushing
    }
}

extension WorkspaceState {
    func retryGitDiscovery() async {
        gitAvailability = nil
        hasStarted = false
        await start()
    }

    @discardableResult
    private func openRepository(
        at url: URL,
        presentsFailure: Bool = true,
        isReplacement: Bool = false
    ) async -> Bool {
        repositoryLoadID += 1
        let loadID = repositoryLoadID
        if isReplacement {
            activeReplacementLoadID = loadID
        }
        isLoadingRepository = true
        defer {
            if loadID == repositoryLoadID {
                isLoadingRepository = false
            }
            if activeReplacementLoadID == loadID {
                activeReplacementLoadID = nil
            }
        }

        do {
            let repository = try await repositoryService.load(url)
            guard loadID == repositoryLoadID else {
                return false
            }
            publishRepository(repository)
            return true
        } catch let error as RepositoryOpenError {
            guard loadID == repositoryLoadID else {
                return false
            }
            if case .gitUnavailable = error {
                gitAvailability = .unavailable
            }
            if presentsFailure {
                presentRepositoryOpenError(error)
            }
            return false
        } catch {
            guard loadID == repositoryLoadID else {
                return false
            }
            if presentsFailure {
                presentRepositoryOpenError(
                    .commandFailed(
                        GitFailureDetails(command: "git", output: error.localizedDescription)
                    )
                )
            }
            return false
        }
    }

    private func savedRepositoryURL() -> URL? {
        guard let savedPath = userDefaults.string(forKey: Self.lastRepositoryPathKey) else {
            return nil
        }
        return URL(filePath: savedPath, directoryHint: .isDirectory)
    }

    private func clearSavedRepository() {
        userDefaults.removeObject(forKey: Self.lastRepositoryPathKey)
    }

    private func publishRepository(_ repository: RepositorySnapshot) {
        let isSameRepository = self.repository?.rootURL == repository.rootURL
        self.repository = repository
        repositoryGeneration += 1
        if !isSameRepository {
            // A message written for one Repository must not follow the user into another, and
            // neither may a New Branch dialog whose start point belongs to the previous one, nor
            // a Fetch Tags dialog: its remote was chosen from the previous Repository's remotes,
            // and confirming it here would contact a remote of this one that the user never saw.
            // A Push dialog goes for both of those reasons at once: its Branch, its remote, and
            // the object its lease expects all belong to the Repository being left behind. A
            // Delete Branch confirmation and a Merge confirmation go the same way: each names
            // branches of the Repository being left, which this one has by those names too.
            commitDraft.clear()
            branchCreation = nil
            branchDeletion = nil
            mergeDraft = nil
            tagFetchSelection = nil
            pushDialog = nil
            pendingFileAction = nil
            isConfirmingHistoryRewrite = false
            isShowingStaleAmendAlert = false
            isShowingStalePushAlert = false
            isShowingStaleBranchDeletionAlert = false
        } else {
            // The same Repository, read again. A dialog that survived that reload has to be
            // checked against it rather than trusted: what it showed is what its own confirmation
            // will act on, and only a comparison can say whether that is still the truth.
            reconcilePushDialog(against: repository)
            reconcileFileAction(against: repository)
            reconcileBranchDeletion(against: repository)
            if !isRewritingHead {
                reconcileAmendDraft()
            }
        }
        updateSelectedChange(for: repository)
        updateHistoryReference(for: repository, isSameRepository: isSameRepository)
        if !isSameRepository {
            // App-owned metadata, so it is read when a Repository arrives rather than on every
            // reload: a reload of the same Repository must not overwrite the time the Fetch that
            // started it just recorded.
            lastFetchDate = storedFetchDate(of: repository.rootURL)
        }
        repositoryFailure = nil
        guard !isUITesting else {
            return
        }
        userDefaults.set(
            repository.rootURL.normalizedFilePath,
            forKey: Self.lastRepositoryPathKey
        )
    }

    // Not private: the configuration extension in WorkspaceState+Configuration.swift needs it.
    //
    // A running Fetch, Pull, or Push holds the Repository the same way a mutation does: they
    // write refs, and a second command landing in the middle of one would race it.
    var canMutateRepository: Bool {
        !isPerformingMutation && !isFetching && !isPulling && !isPushing
            && activeReplacementLoadID == nil
    }

    /// Not private: the Fetch extension keeps app-owned state out of a UI test's defaults through
    /// it, and Swift keeps `private` within one file.
    var isUITesting: Bool {
#if DEBUG
        launchArguments.contains(UITestingArgument.enabled)
#else
        false
#endif
    }
}
