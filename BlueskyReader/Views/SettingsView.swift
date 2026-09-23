//  SettingsView.swift
//  A standard grouped form, presented as a sheet from the reading list.

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("showCommentary") private var showCommentary = false
    @AppStorage("hideReadItems")  private var hideReadItems  = false
    @AppStorage("retentionDays")  private var retentionDays  = 30
    @Query private var items: [LinkItem]
    @State private var showSignOutConfirmation = false

    let handle: String
    let signOut: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Signed in as", value: "@\(handle)")
                    Button("Sign Out", role: .destructive) { showSignOutConfirmation = true }
                }

                Section {
                    Toggle("Show Poster's Commentary", isOn: $showCommentary)
                    Toggle("Hide Read Articles", isOn: $hideReadItems)
                } header: {
                    Text("Reading List")
                } footer: {
                    Text("Commentary is the text the person wrote when they shared the link.")
                }

                Section {
                    Picker("Keep Unread Articles", selection: $retentionDays) {
                        ForEach([7, 30, 90], id: \.self) { Text("\($0) Days").tag($0) }
                    }
                    LabeledContent("Stored Articles", value: "\(items.count)")
                    Button("Remove Read Articles Now") {
                        RetentionService.pruneRead(context: modelContext)
                    }
                    .disabled(!items.contains { $0.isRead && !$0.isSaved })
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Saved articles are never removed.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersionString)
                    Link(destination: URL(string: "https://github.com/ceelew/Skyreader")!) {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Your reading list on this device will be cleared.",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    dismiss()
                    signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
