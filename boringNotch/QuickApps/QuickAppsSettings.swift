import Defaults
import SwiftUI

struct QuickAppsSettings: View {
    @Default(.showQuickApps) private var showQuickApps
    @ObservedObject private var manager = QuickAppsManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show quick apps row", isOn: $showQuickApps)
            } footer: {
                Text("Show a row of application shortcuts below the music player and calendar. Click an icon to open the app.")
            }

            Section {
                if manager.apps.isEmpty {
                    Text("No quick apps yet")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                ForEach(Array(manager.apps.enumerated()), id: \.element.id) { index, app in
                    HStack(spacing: 10) {
                        Image(nsImage: manager.icon(for: app))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: app.name).font(.body)
                            Text(verbatim: app.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 4)
                        Button { manager.move(app, by: -1) } label: {
                            Image(systemName: "chevron.up").frame(width: 18)
                        }
                        .disabled(index == 0)
                        .help("Move app earlier")
                        .accessibilityLabel(Text("Move app earlier"))
                        Button { manager.move(app, by: 1) } label: {
                            Image(systemName: "chevron.down").frame(width: 18)
                        }
                        .disabled(index == manager.apps.count - 1)
                        .help("Move app later")
                        .accessibilityLabel(Text("Move app later"))
                        Button { manager.remove(app) } label: {
                            Image(systemName: "minus.circle").frame(width: 18)
                        }
                        .help("Remove shortcut")
                        .accessibilityLabel(Text("Remove shortcut"))
                    }
                    .buttonStyle(.borderless)
                    .padding(.vertical, 3)
                }
                Button(action: manager.chooseApplications) {
                    Label("Add applications…", systemImage: "plus")
                }
            } header: {
                Text("Quick Apps")
            } footer: {
                Text("Choose multiple apps at once. Use the arrows to reorder them. Removing a shortcut does not uninstall the app. Scroll sideways in the island to reach more apps.")
            }
        }
        .navigationTitle("Quick Apps")
    }
}
