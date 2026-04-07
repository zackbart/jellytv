//
//  RootView.swift
//  JellyTV
//
//  Top-level view that switches between sign-in, signed-in, and reconnecting
//  states based on the SessionStore phase.
//

import SwiftUI
import JellyfinAPI
import Settings
import LiveTV

struct RootView: View {
    @Bindable var sessionStore: SessionStore

    var body: some View {
        Group {
            switch sessionStore.phase {
            case .loading:
                ProgressView()
                    .controlSize(.large)
            case .signedOut:
                SignInFlowView(sessionStore: sessionStore)
            case .signedIn(let user):
                SignedInRootView(user: user, sessionStore: sessionStore)
            case .reconnecting(let user):
                ReconnectingView(lastKnownUser: user, sessionStore: sessionStore)
            }
        }
    }
}

/// Wraps `SignInView` and bridges its terminal `.signedIn` state into the
/// `SessionStore` so the rest of the app reacts.
private struct SignInFlowView: View {
    let sessionStore: SessionStore
    @State private var model: SignInModel

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
        _model = State(initialValue: SignInModel(
            client: sessionStore.client,
            credentials: sessionStore.credentials
        ))
    }

    var body: some View {
        SignInView(model: model)
            .onChange(of: model.state) { _, newState in
                if case .signedIn(let user) = newState {
                    sessionStore.didSignIn(user: user)
                }
            }
    }
}

/// Post sign-in: shows the Live TV guide.
private struct SignedInRootView: View {
    let user: UserDto
    let sessionStore: SessionStore

    var body: some View {
        GuideView(model: GuideModel(client: sessionStore.client))
    }
}

private struct ReconnectingView: View {
    let lastKnownUser: UserDto?
    let sessionStore: SessionStore

    var body: some View {
        VStack(spacing: 40) {
            ProgressView()
                .controlSize(.large)
            Text("Reconnecting…")
                .font(.title)
            Text("Couldn't reach the server. Your sign-in is still saved.")
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 30) {
                Button("Try Again") {
                    Task { await sessionStore.restore() }
                }
                Button("Sign Out") {
                    Task { await sessionStore.signOut() }
                }
            }
        }
        .padding(80)
    }
}
