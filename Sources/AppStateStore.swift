import Foundation

package final class AppStateStore {
    package static let shared = AppStateStore()

    private let key = "parket.appWorkspaces"

    private init() {}

    package func getWorkspace(for bundleIdentifier: String) -> Int? {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return dict[bundleIdentifier]
    }

    package func saveWorkspace(_ workspaceIndex: Int, for bundleIdentifier: String) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        dict[bundleIdentifier] = workspaceIndex
        UserDefaults.standard.set(dict, forKey: key)
    }
}
