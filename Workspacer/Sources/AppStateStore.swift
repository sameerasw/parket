import Foundation

package final class AppStateStore {
    package static let shared = AppStateStore()

    private let legacyKey = "parket.appWorkspaces"
    private let key = "workspacer.appWorkspaces"

    private init() {
        if UserDefaults.standard.object(forKey: key) == nil,
           let legacyDict = UserDefaults.standard.dictionary(forKey: legacyKey) {
            UserDefaults.standard.set(legacyDict, forKey: key)
        }
    }

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
