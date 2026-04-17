import XCTest
@testable import LibreRadio

/// Tests for the platform-agnostic MenuBarState and MenuBarStateBuilder logic.
/// These tests run on iOS Simulator — no AppKit runtime needed.
@MainActor
final class MenuBarServiceTests: XCTestCase {

    // MARK: - MenuBarState

    func testIdleState() {
        let state = MenuBarState(
            stationName: nil,
            trackInfo: nil,
            errorMessage: nil,
            isPlaying: false,
            isLoading: false,
            isPaused: false,
            isError: false,
            volume: 1.0,
            favorites: []
        )

        XCTAssertEqual(state.playPauseTitle, "Play")
        XCTAssertTrue(state.playPauseEnabled)
        XCTAssertFalse(state.stopEnabled)
    }

    func testPlayingState() {
        let state = MenuBarState(
            stationName: "Jazz FM",
            trackInfo: "Miles Davis — So What",
            errorMessage: nil,
            isPlaying: true,
            isLoading: false,
            isPaused: false,
            isError: false,
            volume: 0.5,
            favorites: []
        )

        XCTAssertEqual(state.playPauseTitle, "Pause")
        XCTAssertTrue(state.playPauseEnabled)
        XCTAssertTrue(state.stopEnabled)
    }

    func testLoadingState() {
        let state = MenuBarState(
            stationName: "Radio X",
            trackInfo: nil,
            errorMessage: nil,
            isPlaying: false,
            isLoading: true,
            isPaused: false,
            isError: false,
            volume: 0.75,
            favorites: []
        )

        XCTAssertEqual(state.playPauseTitle, "Play")
        XCTAssertFalse(state.playPauseEnabled)
        XCTAssertTrue(state.stopEnabled)
    }

    func testPausedState() {
        let state = MenuBarState(
            stationName: "Classic FM",
            trackInfo: nil,
            errorMessage: nil,
            isPlaying: false,
            isLoading: false,
            isPaused: true,
            isError: false,
            volume: 1.0,
            favorites: []
        )

        XCTAssertEqual(state.playPauseTitle, "Play")
        XCTAssertTrue(state.playPauseEnabled)
        XCTAssertTrue(state.stopEnabled)
    }

    func testErrorState() {
        let state = MenuBarState(
            stationName: "Broken FM",
            trackInfo: nil,
            errorMessage: "Connection failed",
            isPlaying: false,
            isLoading: false,
            isPaused: false,
            isError: true,
            volume: 1.0,
            favorites: []
        )

        XCTAssertEqual(state.playPauseTitle, "Play")
        XCTAssertTrue(state.playPauseEnabled)
        XCTAssertTrue(state.stopEnabled, "Stop must be enabled in error state so user can clear it")
        XCTAssertEqual(state.errorMessage, "Connection failed")
    }

    // MARK: - Volume Presets

    func testVolumePresetMute() {
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 0.0, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 0)
    }

    func testVolumePreset25() {
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 0.25, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 1)
    }

    func testVolumePreset50() {
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 0.5, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 2)
    }

    func testVolumePreset75() {
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 0.75, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 3)
    }

    func testVolumePreset100() {
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 1.0, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 4)
    }

    func testVolumePresetSnapsToClosest() {
        // 0.13 is closer to 0.25 (dist=0.12) than to 0.0 (dist=0.13)
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 0.13, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 1)
    }

    func testVolumePresetSnapsToMute() {
        // 0.12 is closer to 0.0 (dist=0.12) than to 0.25 (dist=0.13)
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 0.12, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 0)
    }

    func testVolumePresetEquidistantPicksLower() {
        // 0.125 is equidistant from 0.0 (dist=0.125) and 0.25 (dist=0.125).
        // The loop uses strict `<`, so the first match (index 0) wins.
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 0.125, favorites: []
        )
        XCTAssertEqual(state.volumePresetIndex, 0)
    }

    // MARK: - MenuBarStateBuilder (via raw-values overload)

    private func makeStation(name: String = "Test Radio") -> StationDTO {
        TestFixtures.makeStation(name: name)
    }

    func testBuilderIdleState() {
        let state = MenuBarStateBuilder.compute(
            playbackState: .idle,
            trackTitle: nil,
            artist: nil,
            volume: 1.0,
            favorites: []
        )

        XCTAssertNil(state.stationName)
        XCTAssertNil(state.trackInfo)
        XCTAssertNil(state.errorMessage)
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isPaused)
        XCTAssertFalse(state.isError)
        XCTAssertEqual(state.volume, 1.0)
        XCTAssertTrue(state.favorites.isEmpty)
    }

    func testBuilderNilState() {
        let state = MenuBarStateBuilder.compute(
            playbackState: nil,
            trackTitle: nil,
            artist: nil,
            volume: 1.0,
            favorites: []
        )

        XCTAssertNil(state.stationName)
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isPaused)
        XCTAssertFalse(state.isError)
    }

    func testBuilderWithNilViewModels() {
        let state = MenuBarStateBuilder.compute(playerVM: nil, favoritesVM: nil)

        XCTAssertNil(state.stationName)
        XCTAssertNil(state.trackInfo)
        XCTAssertNil(state.errorMessage)
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isPaused)
        XCTAssertFalse(state.isError)
        XCTAssertEqual(state.volume, 1.0)
        XCTAssertTrue(state.favorites.isEmpty)
    }

    func testBuilderLoadingState() {
        let station = makeStation(name: "Loading FM")
        let state = MenuBarStateBuilder.compute(
            playbackState: .loading(station: station),
            trackTitle: nil,
            artist: nil,
            volume: 0.5,
            favorites: []
        )

        XCTAssertEqual(state.stationName, "Loading FM")
        XCTAssertFalse(state.isPlaying)
        XCTAssertTrue(state.isLoading)
        XCTAssertFalse(state.isPaused)
        XCTAssertFalse(state.isError)
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.volume, 0.5)
    }

    func testBuilderPlayingState() {
        let station = makeStation(name: "Jazz FM")
        let state = MenuBarStateBuilder.compute(
            playbackState: .playing(station: station),
            trackTitle: "So What",
            artist: "Miles Davis",
            volume: 0.75,
            favorites: []
        )

        XCTAssertEqual(state.stationName, "Jazz FM")
        XCTAssertTrue(state.isPlaying)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isPaused)
        XCTAssertFalse(state.isError)
        XCTAssertEqual(state.trackInfo, "Miles Davis — So What")
        XCTAssertEqual(state.volume, 0.75)
    }

    func testBuilderPausedState() {
        let station = makeStation(name: "Classic FM")
        let state = MenuBarStateBuilder.compute(
            playbackState: .paused(station: station),
            trackTitle: nil,
            artist: nil,
            volume: 1.0,
            favorites: []
        )

        XCTAssertEqual(state.stationName, "Classic FM")
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.isPaused)
        XCTAssertFalse(state.isError)
    }

    func testBuilderErrorState() {
        let station = makeStation(name: "Broken FM")
        let state = MenuBarStateBuilder.compute(
            playbackState: .error(station: station, message: "Stream unavailable"),
            trackTitle: nil,
            artist: nil,
            volume: 1.0,
            favorites: []
        )

        XCTAssertEqual(state.stationName, "Broken FM")
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isPaused)
        XCTAssertTrue(state.isError)
        XCTAssertEqual(state.errorMessage, "Stream unavailable")
        XCTAssertTrue(state.stopEnabled, "Stop must be enabled in error state")
    }

    // MARK: - Builder: Track Info Composition

    func testBuilderTrackInfoArtistAndTitle() {
        let state = MenuBarStateBuilder.compute(
            playbackState: .idle,
            trackTitle: "Creep",
            artist: "Radiohead",
            volume: 1.0,
            favorites: []
        )

        XCTAssertEqual(state.trackInfo, "Radiohead — Creep")
    }

    func testBuilderTrackInfoTitleOnly() {
        let state = MenuBarStateBuilder.compute(
            playbackState: .idle,
            trackTitle: "Unknown Track",
            artist: nil,
            volume: 1.0,
            favorites: []
        )

        XCTAssertEqual(state.trackInfo, "Unknown Track")
    }

    func testBuilderTrackInfoNone() {
        let state = MenuBarStateBuilder.compute(
            playbackState: .idle,
            trackTitle: nil,
            artist: nil,
            volume: 1.0,
            favorites: []
        )

        XCTAssertNil(state.trackInfo)
    }

    // MARK: - Builder: Favorites Mapping

    func testBuilderFavoritesMapping() {
        let favs = [
            TestFixtures.makeFavoriteStation(uuid: "abc-123", name: "Jazz FM"),
            TestFixtures.makeFavoriteStation(uuid: "def-456", name: "Classic Rock Radio")
        ]

        let state = MenuBarStateBuilder.compute(
            playbackState: .idle,
            trackTitle: nil,
            artist: nil,
            volume: 1.0,
            favorites: favs
        )

        XCTAssertEqual(state.favorites.count, 2)
        XCTAssertEqual(state.favorites[0].uuid, "abc-123")
        XCTAssertEqual(state.favorites[0].name, "Jazz FM")
        XCTAssertEqual(state.favorites[1].uuid, "def-456")
        XCTAssertEqual(state.favorites[1].name, "Classic Rock Radio")
    }

    // MARK: - Favorites (direct state)

    func testFavoritesPopulation() {
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 1.0,
            favorites: [
                MenuBarState.Favorite(uuid: "abc-123", name: "Jazz FM"),
                MenuBarState.Favorite(uuid: "def-456", name: "Classic Rock Radio")
            ]
        )

        XCTAssertEqual(state.favorites.count, 2)
        XCTAssertEqual(state.favorites[0].name, "Jazz FM")
        XCTAssertEqual(state.favorites[1].uuid, "def-456")
    }

    func testEmptyFavorites() {
        let state = MenuBarState(
            stationName: nil, trackInfo: nil, errorMessage: nil,
            isPlaying: false, isLoading: false, isPaused: false, isError: false,
            volume: 1.0, favorites: []
        )

        XCTAssertTrue(state.favorites.isEmpty)
    }

    // MARK: - Track Info Formatting (direct state)

    func testTrackInfoWithArtistAndTitle() {
        let state = MenuBarState(
            stationName: "Radio X", trackInfo: "Radiohead — Creep",
            errorMessage: nil,
            isPlaying: true, isLoading: false, isPaused: false, isError: false,
            volume: 1.0, favorites: []
        )

        XCTAssertEqual(state.trackInfo, "Radiohead — Creep")
    }

    func testTrackInfoTitleOnly() {
        let state = MenuBarState(
            stationName: "Radio X", trackInfo: "Unknown Track",
            errorMessage: nil,
            isPlaying: true, isLoading: false, isPaused: false, isError: false,
            volume: 1.0, favorites: []
        )

        XCTAssertEqual(state.trackInfo, "Unknown Track")
    }

    func testNoTrackInfo() {
        let state = MenuBarState(
            stationName: "Radio X", trackInfo: nil,
            errorMessage: nil,
            isPlaying: true, isLoading: false, isPaused: false, isError: false,
            volume: 1.0, favorites: []
        )

        XCTAssertNil(state.trackInfo)
    }
}
