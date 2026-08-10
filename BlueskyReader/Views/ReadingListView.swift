import SwiftUI

struct ReadingListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Signed in as @\(appModel.currentHandle ?? "unknown")")
                    .font(.headline)
                Text("Reading list UI arrives in M3.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Sign Out", role: .destructive) {
                    Task { await appModel.logout() }
                }
                .padding(.top, 12)
            }
            .navigationTitle("Reading List")
        }
    }
}

#Preview {
    ReadingListView()
        .environment(AppModel(client: ATProtoClient()))
}
