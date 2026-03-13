import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var playerVM: PlayerViewModel

    var body: some View {
        TabView {
            DiscoverView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MiniPlayerView()
                }
                .tabItem {
                    Label("Discover", systemImage: "antenna.radiowaves.left.and.right")
                }

            RecentStationsView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MiniPlayerView()
                }
                .tabItem {
                    Label("Recent", systemImage: "clock")
                }
        }
    }
}
