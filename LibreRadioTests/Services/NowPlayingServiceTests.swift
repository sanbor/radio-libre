import XCTest
import MediaPlayer
@testable import LibreRadio

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

    // MARK: - updateNowPlaying (disabled — Live Activity is the sole lock screen element)

    func testUpdateNowPlayingDoesNotSetInfo() {
        let station = StationDTOTests.makeStation(name: "Jazz FM")
        service.updateNowPlaying(station: station, isPlaying: true)

        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    // MARK: - clearNowPlaying

    func testClearNowPlayingSetsInfoToNil() {
        // Manually set info to verify clearNowPlaying clears it
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: "Test"]
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
