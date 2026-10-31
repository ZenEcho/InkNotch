import Foundation

@main
struct QuickAppsTests {
    static func main() throws {
        let browser = QuickApp(name: "Browser", bundleIdentifier: "test.browser", path: "/Applications/Browser.app", bookmarkData: Data([1, 2]))
        let editor = QuickApp(name: "Editor", bundleIdentifier: "test.editor", path: "/Applications/Editor.app", bookmarkData: Data([3, 4]))
        let movedBrowser = QuickApp(name: "Browser", bundleIdentifier: "test.browser", path: "/Users/test/Applications/Browser.app", bookmarkData: Data([5, 6]))
        var apps: [QuickApp] = []
        apps.addQuickApps([browser, editor, browser])
        precondition(apps == [browser, editor], "Adding the same app twice must not duplicate shortcuts")
        apps.addQuickApps([movedBrowser])
        precondition(apps == [movedBrowser, editor], "Re-selecting a moved app must refresh its path/bookmark and preserve order")

        apps.moveQuickApp(id: editor.id, by: -1)
        precondition(apps == [editor, movedBrowser], "Moving an app earlier must change launch order")
        apps.moveQuickApp(id: editor.id, by: -1)
        apps.moveQuickApp(id: movedBrowser.id, by: 1)
        apps.moveQuickApp(id: "missing", by: 1)
        precondition(apps == [editor, movedBrowser], "Invalid reorder operations must leave the list intact")
        apps.moveQuickApp(id: editor.id, by: 1)
        precondition(apps == [movedBrowser, editor], "Moving later must restore the requested order")

        let data = try JSONEncoder().encode(apps)
        let restored = try JSONDecoder().decode([QuickApp].self, from: data)
        precondition(restored == apps, "Preferences must preserve order and security-scoped bookmarks after relaunch")
        let noBundleID = QuickApp(name: "Custom", bundleIdentifier: nil, path: "/Applications/Custom.app", bookmarkData: Data([7]))
        var custom: [QuickApp] = []
        custom.addQuickApps([noBundleID, noBundleID])
        precondition(custom.count == 1 && custom[0].id == noBundleID.path, "Apps without a bundle identifier must use their path for identity")
        print("Quick Apps: duplicate handling, moved-app refresh, ordering, bounds, and persistence checks passed.")
    }
}
