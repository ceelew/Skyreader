//  LoginView.swift
//  Standard iOS sign-in: app icon and name, a grouped pair of fields, a prominent button.

import SwiftUI

struct LoginView: View {
    @State private var handle = ""
    @State private var appPassword = ""
    @State private var error: String?
    @State private var isSigningIn = false
    @FocusState private var focusedField: Field?
    let signIn: (String, String) async throws -> Void
    var message: String? = nil

    private enum Field { case handle, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                if let message {
                    Label(message, systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 8) {
                    fields
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.destructive)
                            .padding(.horizontal, 4)
                    }
                }

                Button(action: attempt) {
                    Group {
                        if isSigningIn {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSubmit)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Skyreader signs in with an app password, not your account password. You can create one just for this app in Bluesky and revoke it any time.")
                    Link("Create an App Password", destination: URL(string: "https://bsky.app/settings/app-passwords")!)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accent)   // the block's .secondary would grey it out
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Label("Your credentials stay in the iOS Keychain and are sent only to Bluesky.",
                      systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppIconImage")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .accessibilityHidden(true)
            Text("Skyreader")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
            Text("Every link from your Bluesky timeline, as a reading list.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 56)
    }

    private var fields: some View {
        VStack(spacing: 0) {
            fieldRow(systemImage: "at") {
                TextField("Handle (you.bsky.social)", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .focused($focusedField, equals: .handle)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }
            Divider().padding(.leading, 48)
            fieldRow(systemImage: "key") {
                SecureField("App Password", text: $appPassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canSubmit { attempt() } }
            }
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func fieldRow<F: View>(systemImage: String, @ViewBuilder field: () -> F) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            field()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    private var canSubmit: Bool {
        !handle.trimmingCharacters(in: .whitespaces).isEmpty && !appPassword.isEmpty && !isSigningIn
    }

    private func attempt() {
        error = nil; isSigningIn = true
        focusedField = nil
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let trimmedPassword = appPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do { try await signIn(trimmedHandle, trimmedPassword) }
            catch ATProtoError.invalidCredentials {
                self.error = "That handle and app password didn't match."
            } catch ATProtoError.network {
                self.error = "Couldn't reach Bluesky. Check your connection and try again."
            } catch {
                self.error = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}
