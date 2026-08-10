import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var appModel

    @State private var handle: String = ""
    @State private var appPassword: String = ""
    @State private var isSubmitting: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case handle, password
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bluesky Reader")
                        .font(.largeTitle.bold())
                    Text("Sign in with your handle and an app password to build your reading list from your home timeline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Handle (e.g. corey.bsky.social)", text: $handle)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .handle)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding(12)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))

                    SecureField("App password", text: $appPassword)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await submit() } }
                        .padding(12)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
                }

                if let error = appModel.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isSubmitting)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Need an app password?")
                        .font(.footnote.bold())
                    Text("Go to Bluesky → Settings → Privacy and Security → App Passwords to create one. Don't use your main account password.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Open Bluesky settings", destination: URL(string: "https://bsky.app/settings/app-passwords")!)
                        .font(.footnote)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private var canSubmit: Bool {
        !handle.trimmingCharacters(in: .whitespaces).isEmpty && !appPassword.isEmpty
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let cleanedHandle = handle.trimmingCharacters(in: .whitespaces)
        await appModel.login(handle: cleanedHandle, appPassword: appPassword)
    }
}

#Preview {
    LoginView()
        .environment(AppModel(client: ATProtoClient()))
}
