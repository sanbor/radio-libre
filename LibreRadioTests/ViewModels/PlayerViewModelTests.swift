import XCTest
import AVFoundation
@testable import LibreRadio

@MainActor
final class PlayerViewModelTests: XCTestCase {

    private var discovery: ServerDiscoveryService!
    private var radioBrowserService: RadioBrowserService!
    private var audioService: AudioPlayerService!
    private var historyService: HistoryService!
    private var historyDefaults: UserDefaults!
    private var vm: PlayerViewModel!

    override func setUp() async throws {
        discovery = ServerDiscoveryService()
        await discovery.setServers(["mock.api.radio-browser.info"])

        let session = TestFixtures.makeMockSession()
        radioBrowserService = RadioBrowserService(discovery: discovery, session: session)

        let nowPlayingService = NowPlayingService()
        audioService = AudioPlayerService(
            player: AVPlayer(),
            service: radioBrowserService,
            nowPlayingService: nowPlayingService
        )

        historyDefaults = UserDefaults(suiteName: "PlayerViewModelTests")!
        historyDefaults.removePersistentDomain(forName: "PlayerViewModelTests")
        historyService = HistoryService(defaults: historyDefaults)

        vm = PlayerViewModel(
            audioService: audioService,
            radioBrowserService: radioBrowserService,
            historyService: historyService
        )

        // Default mock handler for click tracking
        MockURLProtocol.requestHandler = { request in
            let json = """
            {"ok": true, "message": "OK", "stationuuid": "test", "name": "Test", "url": "http://test"}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        historyDefaults.removePersistentDomain(forName: "PlayerViewModelTests")
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertNil(vm.currentStation)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.state, .idle)
    }

    // MARK: - Play

    func testPlaySetsLoadingState() {
        let station = TestFixtures.makeStation()
        vm.play(station: station)

        XCTAssertEqual(vm.currentStation, station)
        XCTAssertTrue(vm.isLoading)
        XCTAssertFalse(vm.isPlaying)
    }

    func testPlayWithInvalidURLSetsError() {
        let station = StationDTOTests.makeStation(
            uuid: "bad",
            name: "Bad",
            url: "",
            urlResolved: nil
        )
        vm.play(station: station)

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - Toggle

    func testToggleFromPausedReconnects() {
        let station = TestFixtures.makeStation()
        vm.play(station: station)
        audioService.pause()

        vm.togglePlayPause()
        XCTAssertTrue(vm.isLoading)
    }

    func testToggleFromIdleDoesNothing() {
        vm.togglePlayPause()
        XCTAssertEqual(vm.state, .idle)
    }

    // MARK: - Stop

    func testStopReturnsToIdle() {
        let station = TestFixtures.makeStation()
        vm.play(station: station)

        vm.stop()
        XCTAssertNil(vm.currentStation)
        XCTAssertEqual(vm.state, .idle)
    }

    // MARK: - Vote

    func testVoteReturnsResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            let json = """
            {"ok": true, "message": "voted for station successfully"}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let station = TestFixtures.makeStation()
        let result = try await vm.vote(station: station)
        XCTAssertTrue(result.ok)
    }

    func testVoteThrowsOnServerError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let station = TestFixtures.makeStation()
        do {
            _ = try await vm.vote(station: station)
            XCTFail("Expected error")
        } catch {
            // Expected
        }
    }

    // MARK: - Error Message

    func testErrorMessageNilForNonErrorStates() {
        XCTAssertNil(vm.errorMessage) // idle

        let station = TestFixtures.makeStation()
        vm.play(station: station)
        XCTAssertNil(vm.errorMessage) // loading
    }

    func testErrorMessagePopulatedOnError() {
        let station = StationDTOTests.makeStation(
            uuid: "bad",
            name: "Bad",
            url: "",
            urlResolved: nil
        )
        vm.play(station: station)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - History Recording

    func testPlayRecordsHistory() async throws {
        let station = TestFixtures.makeStation(uuid: "history-test", name: "History Station")
        vm.play(station: station)

        // Await the history write task instead of sleeping — Task.sleep is flaky on CI runners
        await vm.historyTask?.value

        let entries = await historyService.allEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].stationuuid, "history-test")
    }

    // MARK: - State Forwarding

    func testStateMatchesAudioService() {
        XCTAssertEqual(vm.state, audioService.state)

        let station = TestFixtures.makeStation()
        vm.play(station: station)
        XCTAssertEqual(vm.state, audioService.state)

        vm.stop()
        XCTAssertEqual(vm.state, audioService.state)
    }
}
