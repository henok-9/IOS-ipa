import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: AntigravAPIClient
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "bolt.fill")
                }
                .tag(0)

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "checkmark.seal")
                }
                .badge(api.reviewQueue.count)
                .tag(1)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "play.square.stack")
                }
                .tag(2)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(3)
        }
        .tint(MaterialTheme.primary)
        .task {
            await api.checkServerStatus()
            await api.fetchPoses()
            await api.fetchReviewQueue()
        }
    }
}
