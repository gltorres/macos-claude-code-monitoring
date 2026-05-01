import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var lastError: String?
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let new = try await ClaudeUsageClient.shared.fetchUsage()
            snapshot = new
            lastError = nil
            lastUpdated = Date()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
