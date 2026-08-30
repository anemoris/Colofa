////
//  WorkspaceRootView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceRootView: View {
    @Environment(WorkspaceState.self) private var state
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var state = state

        Group {
            if case .unavailable? = state.gitAvailability {
                GitUnavailableView()
            } else {
                RepositoryWorkspaceView()
            }
        }
        .toolbar {
            if case .available? = state.gitAvailability {
                RepositoryToolbar()
            }
        }
        .fileImporter(
            isPresented: $state.isPresentingRepositoryPicker,
            allowedContentTypes: [.folder]
        ) { result in
            Task {
                await state.handleRepositorySelection(result)
            }
        }
        .alert(
            String(localized: state.repositoryFailureTitle ?? .repositoryOpenFailed),
            isPresented: $state.isShowingRepositoryOpenError
        ) {
            Button(.chooseAnotherRepository, action: state.chooseAnotherRepository)
            Button(.cancel, role: .cancel, action: state.dismissRepositoryOpenError)
        } message: {
            Text(state.repositoryFailureMessage ?? .repositoryOpenFailedDescription)
        }
        .alert(
            String(localized: state.repositoryFailureTitle ?? .gitOperationFailed),
            isPresented: $state.isShowingRepositoryMutationError
        ) {
            if state.canShowRepositoryFailureDetails {
                Button(.viewDetails, action: state.showRepositoryMutationErrorDetails)
            }
            Button(.ok, role: .cancel, action: state.dismissRepositoryMutationError)
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(state.repositoryFailureMessage ?? .gitMutationFailedDescription)
        }
        .sheet(isPresented: $state.isCreatingBranch) {
            NewBranchSheet()
        }
        .sheet(isPresented: $state.isChoosingTagFetchRemote) {
            FetchTagsSheet()
        }
        .sheet(isPresented: $state.isConfirmingPush) {
            PushConfirmationSheet()
        }
        .sheet(isPresented: $state.isChoosingPublishRemote) {
            PublishRemoteSheet()
        }
        .sheet(isPresented: $state.isPresentingAuthenticationRequest) {
            AuthenticationRequestSheet()
        }
        .alert(
            String(localized: .amendCancelledHeadChangedTitle),
            isPresented: $state.isShowingStaleAmendAlert
        ) {
        } message: {
            Text(.amendCancelledHeadChangedMessage)
        }
        .alert(
            String(localized: .pushCancelledRepositoryChangedTitle),
            isPresented: $state.isShowingStalePushAlert
        ) {
        } message: {
            Text(.pushCancelledRepositoryChangedMessage)
        }
        .task {
            await state.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            scenePhaseChanged(to: newPhase)
        }
    }

    private func scenePhaseChanged(to newPhase: ScenePhase) {
        guard newPhase == .active else {
            return
        }
        Task {
            await state.refresh()
        }
    }
}

#Preview {
    WorkspaceRootView()
        .environment(WorkspaceState())
        .frame(
            width: LayoutMetrics.defaultWindowWidth,
            height: LayoutMetrics.defaultWindowHeight
        )
}
