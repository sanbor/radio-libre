import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitorService

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

            SearchView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MiniPlayerView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            BrowseView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MiniPlayerView()
                }
                .tabItem {
                    Label("Browse", systemImage: "list.bullet")
                }

            FavoritesView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MiniPlayerView()
                }
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !networkMonitor.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("No Internet Connection")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red)
            }
        }
    }
}
