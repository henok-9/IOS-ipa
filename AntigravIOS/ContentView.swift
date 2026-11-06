import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: AntigravAPIClient
    @State private var selectedTab: Int = 0

    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                ScanView()
            case 1:
                ReviewView()
            case 2:
                LibraryView()
            case 3:
                HistoryView()
            default:
                ScanView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            // Sleek Material You Navigation Bar
            VStack(spacing: 0) {
                Divider()
                    .background(MaterialTheme.surfaceContainerHigh)

                HStack(spacing: 0) {
                    navItem(tab: 0, title: "Scan", icon: "bolt.fill")
                    navItem(tab: 1, title: "Review", icon: "checkmark.seal", badge: api.reviewQueue.count)
                    navItem(tab: 2, title: "Library", icon: "play.square.stack")
                    navItem(tab: 3, title: "History", icon: "clock.arrow.circlepath")
                }
                .padding(.top, 6)
                .padding(.bottom, 4)
                .background(MaterialTheme.surface)
            }
        }
        .preferredColorScheme(.light)
        .task {
            await api.checkServerStatus()
            await api.fetchPoses()
            await api.fetchReviewQueue()
        }
    }

    @ViewBuilder
    private func navItem(tab: Int, title: String, icon: String, badge: Int = 0) -> some View {
        let isSelected = selectedTab == tab
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    }
                    .frame(width: 52, height: 26)
                    .background(isSelected ? MaterialTheme.primaryContainer : Color.clear)
                    .foregroundColor(isSelected ? MaterialTheme.onPrimaryContainer : MaterialTheme.textSecondary)
                    .clipShape(Capsule())

                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(MaterialTheme.onWarningContainer)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(MaterialTheme.warningContainer)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? MaterialTheme.textPrimary : MaterialTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
