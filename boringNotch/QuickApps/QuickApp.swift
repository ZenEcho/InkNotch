import Foundation

/// Stores a shortcut, never a copy of the application itself.
struct QuickApp: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let bundleIdentifier: String?
    let path: String
    var bookmarkData: Data

    var id: String { bundleIdentifier ?? path }
}

extension Array where Element == QuickApp {
    /// Re-selecting the same app refreshes its bookmark without moving it.
    mutating func addQuickApps(_ candidates: [QuickApp]) {
        for candidate in candidates {
            if let index = firstIndex(where: { $0.id == candidate.id }) {
                self[index] = candidate
            } else {
                append(candidate)
            }
        }
    }

    mutating func moveQuickApp(id: String, by offset: Int) {
        guard let source = firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard indices.contains(destination) else { return }
        let app = remove(at: source)
        insert(app, at: destination)
    }
}
