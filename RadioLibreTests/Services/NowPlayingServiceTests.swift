import XCTest
import MediaPlayer
@testable import RadioLibre

@MainActor
final class NowPlayingServiceTests: XCTestCase {

    private var service: NowPlayingService!

    override func setUp() {
        service = NowPlayingService()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    override func tearDown() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - updateNowPlaying

    func testUpdateNowPlayingSetsTitle() {
        let station = StationDTOTests.makeStation(name: "Jazz FM")
        service.updateNowPlaying(station: station, isPlaying: true)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "Jazz FM")
    }

    func testUpdateNowPlayingSetsArtistWithFlagAndCountry() {
        let station = StationDTOTests.makeStation(country: "France", countrycode: "FR")
        service.updateNowPlaying(station: station, isPlaying: true)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "🇫🇷 France")
    }

    func testUpdateNowPlayingSetsArtistWithCountryOnly() {
        let station = StationDTOTests.makeStation(country: "France")
        service.updateNowPlaying(station: station, isPlaying: true)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "France")
    }

    func testUpdateNowPlayingSetsArtistEmptyWhenNoCountry() {
        let station = StationDTOTests.makeStation()
        service.updateNowPlaying(station: station, isPlaying: true)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "")
    }

    func testUpdateNowPlayingSetsAlbumFromTags() {
        let station = StationDTOTests.makeStation(tags: "rock,jazz,blues,classical")
        service.updateNowPlaying(station: station, isPlaying: true)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        // prefix(3) of tagList joined by ", "
        XCTAssertEqual(info?[MPMediaItemPropertyAlbumTitle] as? String, "rock, jazz, blues")
    }

    func testUpdateNowPlayingSetsLiveStream() {
        let station = TestFixtures.makeStation()
        service.updateNowPlaying(station: station, isPlaying: true)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyIsLiveStream] as? Bool, true)
    }

    func testUpdateNowPlayingIsPlayingSetsRateOne() {
        let station = TestFixtures.makeStation()
        service.updateNowPlaying(station: station, isPlaying: true)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
    }

    func testUpdateNowPlayingNotPlayingSetsRateZero() {
        let station = TestFixtures.makeStation()
        service.updateNowPlaying(station: station, isPlaying: false)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0.0)
    }

    // MARK: - clearNowPlaying

    func testClearNowPlayingSetsInfoToNil() {
        let station = TestFixtures.makeStation()
        service.updateNowPlaying(station: station, isPlaying: true)
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)

        service.clearNowPlaying()
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    // MARK: - Remote Commands

    func testRemoteCommandsEnabled() {
        let center = MPRemoteCommandCenter.shared()
        XCTAssertTrue(center.playCommand.isEnabled)
        XCTAssertTrue(center.pauseCommand.isEnabled)
        XCTAssertTrue(center.stopCommand.isEnabled)
        XCTAssertTrue(center.togglePlayPauseCommand.isEnabled)
    }

    func testNextPreviousCommandsEnabled() {
        let center = MPRemoteCommandCenter.shared()
        XCTAssertTrue(center.nextTrackCommand.isEnabled)
        XCTAssertTrue(center.previousTrackCommand.isEnabled)
    }

    // MARK: - Player ViewModel Wiring

    func testSetPlayerViewModelStoresReference() {
        let audioService = AudioPlayerService()
        let playerVM = PlayerViewModel(audioService: audioService)
        service.setPlayerViewModel(playerVM)
        XCTAssertNotNil(service.playerViewModel)
    }

    func testPlayerViewModelIsWeak() {
        let audioService = AudioPlayerService()
        var playerVM: PlayerViewModel? = PlayerViewModel(audioService: audioService)
        service.setPlayerViewModel(playerVM!)
        playerVM = nil
        XCTAssertNil(service.playerViewModel)
    }
}
