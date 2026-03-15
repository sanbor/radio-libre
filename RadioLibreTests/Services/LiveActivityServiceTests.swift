import XCTest
@testable import RadioLibre

@available(iOS 16.2, *)
@MainActor
final class LiveActivityServiceTests: XCTestCase {

    // MARK: - end() is no-op when no activity

    func testEndWithoutActivityDoesNotCrash() {
        let service = LiveActivityService.shared
        // Should not throw or crash when no activity is running
        service.end()
    }

    // MARK: - ContentState construction

    func testContentStateFromStationWithAllFields() {
        let station = StationDTOTests.makeStation(
            name: "Jazz FM",
            countrycode: "FR",
            codec: "MP3",
            bitrate: 128
        )

        let state = RadioActivityAttributes.ContentState(
            stationName: station.name,
            codec: station.codec,
            bitrateLabel: station.bitrateLabel,
            flagEmoji: station.flagEmoji,
            isPlaying: true,
            isLoading: false,
            isBuffering: false
        )

        XCTAssertEqual(state.stationName, "Jazz FM")
        XCTAssertEqual(state.codec, "MP3")
        XCTAssertEqual(state.bitrateLabel, "128k")
        XCTAssertEqual(state.flagEmoji, "🇫🇷")
        XCTAssertTrue(state.isPlaying)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isBuffering)
    }

    func testContentStateFromStationWithNilFields() {
        let station = StationDTOTests.makeStation(name: "Minimal")

        let state = RadioActivityAttributes.ContentState(
            stationName: station.name,
            codec: station.codec,
            bitrateLabel: station.bitrateLabel,
            flagEmoji: station.flagEmoji,
            isPlaying: false,
            isLoading: true,
            isBuffering: false
        )

        XCTAssertEqual(state.stationName, "Minimal")
        XCTAssertNil(state.codec)
        XCTAssertEqual(state.bitrateLabel, "—")
        XCTAssertNil(state.flagEmoji)
        XCTAssertFalse(state.isPlaying)
        XCTAssertTrue(state.isLoading)
    }

    // MARK: - ContentState Codable round-trip

    func testContentStateCodableRoundTrip() throws {
        let state = RadioActivityAttributes.ContentState(
            stationName: "Rock FM",
            codec: "AAC",
            bitrateLabel: "256k",
            flagEmoji: "🇩🇪",
            isPlaying: true,
            isLoading: false,
            isBuffering: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(RadioActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(state, decoded)
    }

    // MARK: - ContentState Hashable

    func testContentStateHashableEqual() {
        let a = RadioActivityAttributes.ContentState(
            stationName: "Jazz FM", codec: "MP3", bitrateLabel: "128k",
            flagEmoji: "🇫🇷", isPlaying: true, isLoading: false, isBuffering: false
        )
        let b = RadioActivityAttributes.ContentState(
            stationName: "Jazz FM", codec: "MP3", bitrateLabel: "128k",
            flagEmoji: "🇫🇷", isPlaying: true, isLoading: false, isBuffering: false
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testContentStateHashableNotEqual() {
        let a = RadioActivityAttributes.ContentState(
            stationName: "Jazz FM", codec: "MP3", bitrateLabel: "128k",
            flagEmoji: "🇫🇷", isPlaying: true, isLoading: false, isBuffering: false
        )
        let b = RadioActivityAttributes.ContentState(
            stationName: "Rock FM", codec: "AAC", bitrateLabel: "256k",
            flagEmoji: "🇩🇪", isPlaying: false, isLoading: true, isBuffering: false
        )
        XCTAssertNotEqual(a, b)
    }
}
