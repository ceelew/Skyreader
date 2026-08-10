import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("showPostText") private var showPostText: Bool = true
    @AppStorage("hideReadItems") private var hideReadItems: Bool = false
    @AppStorage("retentionDays") private var retentionDays: Int = 30

    @State private var didPrune = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Handle", value: "@\(appModel.currentHandle ?? "unknown")")
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await appModel.logout()
                            dismiss()
                        }
                    }
                }

                Section("Display") {
                    Toggle("Show post commentary", isOn: $showPostText)
                    Toggle("Hide read items", isOn: $hideReadItems)
                }

                Section {
                    Stepper("Keep unread items for \(retentionDays) days", value: $retentionDays, in: 7...90, step: 7)
                    Button("Prune Now") {
                        RetentionService.pruneOldUnread(context: modelContext, retentionDays: retentionDays)
                        didPrune = true
                    }
                    if didPrune {
                        Text("Old unread items removed.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Retention")
                } footer: {
                    Text("Unread items older than the retention window are removed on launch. Saved items are never removed.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(client: ATProtoClient()))
}
