import Defaults
import SwiftUI

struct QuickAppsBar: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var manager = QuickAppsManager.shared

    var body: some View {
        VStack(spacing: 7) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            HStack(spacing: 8) {
                if manager.apps.isEmpty {
                    Button(action: manager.showSettings) {
                        Label("Add quick apps", systemImage: "plus.app")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(manager.apps) { app in
                                QuickAppButton(app: app) {
                                    manager.launch(app) { vm.close() }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                Button(action: manager.showSettings) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Manage quick apps")
                .accessibilityLabel(Text("Manage quick apps"))
            }
            .padding(.horizontal, 6)
        }
        .frame(height: quickAppsBarHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Quick Apps"))
    }
}

private struct QuickAppButton: View {
    let app: QuickApp
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(nsImage: QuickAppsManager.shared.icon(for: app))
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .padding(4)
                .background(hovering ? .white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .scaleEffect(hovering ? 1.06 : 1)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(app.name)
        .accessibilityLabel(Text(verbatim: app.name))
        .onHover { hovering = $0 }
    }
}
