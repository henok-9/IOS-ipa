import SwiftUI

@main
struct AntigravApp: App {
    @StateObject private var apiClient = AntigravAPIClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(apiClient)
                .preferredColorScheme(.light)
        }
    }
}
