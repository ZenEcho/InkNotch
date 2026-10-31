import AppKit
import Combine
import Defaults
import UniformTypeIdentifiers

extension QuickApp: Defaults.Serializable {}

extension Defaults.Keys {
    static let showQuickApps = Key<Bool>("showQuickApps", default: true)
    static let quickApps = Key<[QuickApp]>("quickApps", default: [])
}

extension Notification.Name {
    static let showQuickAppsSettings = Notification.Name("com.boringNotch.showQuickAppsSettings")
}

@MainActor
final class QuickAppsManager: ObservableObject {
    static let shared = QuickAppsManager()

    @Published private(set) var apps: [QuickApp] = Defaults[.quickApps]
    private var subscription: AnyCancellable?
    private var icons: [String: NSImage] = [:]

    private init() {
        subscription = Defaults.publisher(.quickApps)
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                self?.apps = change.newValue
                self?.icons.removeAll()
            }
    }

    func showSettings() {
        SettingsWindowController.shared.showWindow()
        NotificationCenter.default.post(name: .showQuickAppsSettings, object: nil)
    }

    func chooseApplications() {
        // Keep the island open while an application picker is being presented.
        SharingStateManager.shared.beginInteraction()
        defer { SharingStateManager.shared.endInteraction() }

        let panel = NSOpenPanel()
        panel.title = String(localized: "Add quick apps")
        panel.message = String(localized: "Choose the applications you want to open from the island. You can select more than one.")
        panel.prompt = String(localized: "Add")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }

        var candidates: [QuickApp] = []
        var failedNames: [String] = []
        for url in panel.urls {
            do {
                let bookmark = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                let displayName = FileManager.default.displayName(atPath: url.path)
                let name = displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
                candidates.append(QuickApp(
                    name: name,
                    bundleIdentifier: Bundle(url: url)?.bundleIdentifier,
                    path: url.standardizedFileURL.path,
                    bookmarkData: bookmark
                ))
            } catch {
                failedNames.append(url.deletingPathExtension().lastPathComponent)
            }
        }

        var updated = apps
        updated.addQuickApps(candidates)
        save(updated)
        if !candidates.isEmpty { Defaults[.showQuickApps] = true }
        if !failedNames.isEmpty {
            showError(
                title: String(localized: "Some applications could not be added"),
                message: failedNames.joined(separator: "、")
            )
        }
    }

    func remove(_ app: QuickApp) {
        save(apps.filter { $0.id != app.id })
    }

    func move(_ app: QuickApp, by offset: Int) {
        var updated = apps
        updated.moveQuickApp(id: app.id, by: offset)
        save(updated)
    }

    func icon(for app: QuickApp) -> NSImage {
        if let cached = icons[app.id] { return cached }
        let image: NSImage
        if let url = resolvedURL(for: app) {
            image = url.accessSecurityScopedResource { NSWorkspace.shared.icon(forFile: $0.path) }
        } else {
            image = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        icons[app.id] = image
        return image
    }

    func launch(_ app: QuickApp, onSuccess: @escaping @MainActor @Sendable () -> Void) {
        guard let url = resolvedURL(for: app, refreshBookmark: true) else {
            showError(
                title: String(localized: "Could not open application"),
                message: String(localized: "This application is no longer available. Remove its shortcut or add it again in Quick Apps settings.")
            )
            return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if accessed { url.stopAccessingSecurityScopedResource() }
                if let error {
                    self?.showError(title: String(localized: "Could not open application"), message: error.localizedDescription)
                } else {
                    onSuccess()
                }
            }
        }
    }

    private func resolvedURL(for app: QuickApp, refreshBookmark: Bool = false) -> URL? {
        var stale = false
        if let url = try? URL(resolvingBookmarkData: app.bookmarkData,
                              options: [.withSecurityScope, .withoutUI],
                              relativeTo: nil, bookmarkDataIsStale: &stale) {
            let exists = url.accessSecurityScopedResource { FileManager.default.fileExists(atPath: $0.path) }
            if exists {
                if stale && refreshBookmark {
                    url.accessSecurityScopedResource { scopedURL in
                        if let bookmark = try? scopedURL.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]),
                           let index = apps.firstIndex(where: { $0.id == app.id }) {
                            var updated = apps
                            updated[index].bookmarkData = bookmark
                            save(updated)
                        }
                    }
                }
                return url
            }
        }
        // Launch Services follows apps moved or replaced during an app update.
        if let identifier = app.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            return url
        }
        let original = URL(fileURLWithPath: app.path)
        return FileManager.default.fileExists(atPath: original.path) ? original : nil
    }

    private func save(_ updated: [QuickApp]) {
        guard updated != apps else { return }
        apps = updated
        icons.removeAll()
        Defaults[.quickApps] = updated
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
