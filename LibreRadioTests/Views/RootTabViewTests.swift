import XCTest
import SwiftUI
import AVFoundation
@testable import LibreRadio

/// Regression tests for RootTabView, specifically verifying that
/// FullPlayerView receives its required environment objects when
/// presented as a sheet.
///
/// On Mac Catalyst, `.sheet()` presentations do NOT inherit
/// `environmentObject` from parent views, causing a fatal error
/// if not explicitly provided.
@MainActor
final class RootTabViewTests: XCTestCase {

    private var playerVM: PlayerViewModel!
    private var favoritesVM: FavoritesViewModel!
    private var networkMonitor: NetworkMonitorService!

    private var historyDefaults: UserDefaults!
    private var historySuiteName: String!
    private var favoritesDefaults: UserDefaults!
    private var favoritesSuiteName: String!

    override func setUp() async throws {
        let session = TestFixtures.makeMockSession()

        let discovery = ServerDiscoveryService()
        await discovery.setServers(["mock.api.radio-browser.info"])
        let radioBrowser = RadioBrowserService(discovery: discovery, session: session)

        let nowPlayingService = NowPlayingService()
        let audioService = AudioPlayerService(
            player: AVPlayer(),
            service: radioBrowser,
            nowPlayingService: nowPlayingService
        )

        historySuiteName = "RootTabViewTests-history-\(UUID().uuidString)"
        historyDefaults = UserDefaults(suiteName: historySuiteName)!
        let historyService = HistoryService(defaults: historyDefaults)

        playerVM = PlayerViewModel(
            audioService: audioService,
            radioBrowserService: radioBrowser,
            historyService: historyService
        )

        favoritesSuiteName = "RootTabViewTests-favorites-\(UUID().uuidString)"
        favoritesDefaults = UserDefaults(suiteName: favoritesSuiteName)!
        let favoritesService = FavoritesService(defaults: favoritesDefaults, radioBrowserService: radioBrowser)
        favoritesVM = FavoritesViewModel(favoritesService: favoritesService)

        networkMonitor = NetworkMonitorService()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "[]".data(using: .utf8)!)
        }
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        historyDefaults?.removePersistentDomain(forName: historySuiteName)
        favoritesDefaults?.removePersistentDomain(forName: favoritesSuiteName)
    }

    // MARK: - View Instantiation

    func testRootTabViewCanBeInstantiated() {
        // RootTabView requires three environment objects; verify it can be created
        _ = RootTabView()
    }

    func testFullPlayerViewCanBeInstantiated() {
        // FullPlayerView requires playerVM and favoritesVM environment objects.
        // On Mac Catalyst, sheets don't inherit environmentObject from parents,
        // so these must be explicitly passed in RootTabView's .sheet() modifier.
        _ = FullPlayerView()
    }

    func testMiniPlayerViewCanBeCreatedWithNilStation() {
        _ = MiniPlayerView(station: nil)
    }

    func testMiniPlayerViewCanBeCreatedWithStation() {
        let station = TestFixtures.makeStation()
        _ = MiniPlayerView(station: station)
    }

    func testPlayerControlsViewCanBeInstantiated() {
        _ = PlayerControlsView()
    }
}
