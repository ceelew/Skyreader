//  SettingsView.swift
//  Same list vocabulary as the reading list: hairline rules, tracked uppercase headers.

import SwiftUI

struct SettingsView: View {
    @AppStorage("showCommentary") private var showCommentary = false
    @AppStorage("hideReadItems")  private var hideReadItems  = false
    @AppStorage("retentionDays")  private var retentionDays  = 30
    let handle: String
    let storedCount: Int
    let signOut: () -> Void
    let pruneRead: () -> Void
    @State private var showSignOutConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.masthead)
                    .tracking(-0.5)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Space.xl)
                    .padding(.top, 18)

                header("Account")
                row { Text("Signed in as"); Spacer(); Text("@\(handle)").foregroundStyle(Color.inkSecondary) }
                divider(inset: true)
                Button { showSignOutConfirmation = true } label: {
                    row { Text("Sign out").foregroundStyle(Color.destructive); Spacer() }
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Sign out? Your reading list on this device will be cleared.",
                    isPresented: $showSignOutConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Sign Out", role: .destructive, action: signOut)
                    Button("Cancel", role: .cancel) {}
                }
                divider()

                header("Reading list")
                row { Toggle("Show poster's commentary", isOn: $showCommentary).tint(.accent) }
                divider(inset: true)
                row { Toggle("Hide read items", isOn: $hideReadItems).tint(.accent) }
                divider()

                header("Storage")
                row {
                    Text("Keep unread items"); Spacer()
                    Picker("", selection: $retentionDays) {
                        ForEach([7, 30, 90], id: \.self) { Text("\($0) days").tag($0) }
                    }.labelsHidden().tint(Color.inkSecondary)
                }
                divider(inset: true)
                Button(action: pruneRead) {
                    row {
                        Text("Remove read items now").foregroundStyle(Color.accent); Spacer()
                        Text("\(storedCount) stored").font(.subheadline).foregroundStyle(Color.inkTertiary)
                    }
                }.buttonStyle(.plain)
                divider()
                Text("Saved articles are never removed.")
                    .font(.caption)
                    .foregroundStyle(Color.inkTertiary)
                    .padding(.horizontal, Space.xl)
                    .padding(.top, 10)

                HStack {
                    Text("Skyreader \(Bundle.main.appVersionString)")
                    Spacer()
                    Link("Source ↗", destination: URL(string: "https://github.com/ceelew/Skyreader")!)
                        .foregroundStyle(Color.accentStrong)
                }
                .font(.caption)
                .foregroundStyle(Color.inkTertiary)
                .padding(.horizontal, Space.xl)
                .padding(.top, 26)
            }
        }
        .background(Color.paper)
        .navigationTitle("")
    }

    private func header(_ t: String) -> some View {
        Text(t)
            .font(.dayHeader).textCase(.uppercase).tracking(0.9)
            .foregroundStyle(Color.inkTertiary)
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xxl).padding(.bottom, 10)
    }
    private func divider(inset: Bool = false) -> some View {
        Rectangle().fill(Color.rule).frame(height: 0.5).padding(.leading, inset ? Space.xl : 0)
    }
    private func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: Space.l) { content() }
            .font(.body).foregroundStyle(Color.ink)
            .padding(.horizontal, Space.xl).padding(.vertical, 14)
            .frame(minHeight: 44)
    }
}
