//  LoginView.swift
//  Typographic form: no boxed fields, just labels over hairline-underlined text.

import SwiftUI

struct LoginView: View {
    @State private var handle = ""
    @State private var appPassword = ""
    @State private var error: String?
    @State private var isSigningIn = false
    let signIn: (String, String) async throws -> Void
    var message: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Skyreader")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .tracking(-0.7)
                    .foregroundStyle(Color.ink)
                Text("Every link from your Bluesky timeline, as a reading list.")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(.top, 44)

            VStack(alignment: .leading, spacing: 26) {
                field("Handle", hasError: false) {
                    TextField("you.bsky.social", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                }
                field("App password", hasError: error != nil) {
                    SecureField("xxxx-xxxx-xxxx-xxxx", text: $appPassword)
                        .textContentType(.password)
                }
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color.destructive)
                        .padding(.top, -14)
                }
            }
            .padding(.top, 36)

            Button(action: attempt) {
                Text(isSigningIn ? "Signing in…" : "Sign in")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentStrong))
            }
            .disabled(handle.isEmpty || appPassword.isEmpty || isSigningIn)
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 10) {
                Text("Skyreader signs in with an *app password*, not your account password. Bluesky lets you create one just for this app, and revoke it any time.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                Link(destination: URL(string: "https://bsky.app/settings/app-passwords")!) {
                    Text("Create an app password ↗")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accent)
                }
            }
            .padding(.top, 22)

            Spacer(minLength: Space.l)

            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(Color.rule).frame(height: 0.5)
                Text("Credentials are held in the iOS Keychain and sent only to bsky.social. Skyreader has no server.")
                    .font(.caption)
                    .foregroundStyle(Color.inkTertiary)
                    .padding(.top, Space.l)
            }
        }
        .padding(.horizontal, Space.xxl)
        .padding(.bottom, 34)
        .background(Color.paper)
    }

    @ViewBuilder
    private func field<F: View>(_ label: String, hasError: Bool, @ViewBuilder content: () -> F) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Color.inkTertiary)
            content()
                .font(.body)
                .foregroundStyle(Color.ink)
                .frame(minHeight: 24)
            Rectangle()
                .fill(hasError ? Color.destructive : Color.rule)
                .frame(height: hasError ? 1 : 0.5)
        }
    }

    private func attempt() {
        error = nil; isSigningIn = true
        Task {
            do { try await signIn(handle, appPassword) }
            catch { self.error = "That handle and app password didn't match. Check for a stray space at the end." }
            isSigningIn = false
        }
    }
}
