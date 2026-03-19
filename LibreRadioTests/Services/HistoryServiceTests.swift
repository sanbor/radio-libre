import XCTest
@testable import LibreRadio

final class HistoryServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var service: HistoryService!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "HistoryServiceTests")!
        defaults.removePersistentDomain(forName: "HistoryServiceTests")
        service = HistoryService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "HistoryServiceTests")
    }

    // MARK: - Record Play

    func testRecordPlayAddsEntry() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await service.recordPlay(station: station)

        let entries = await service.allEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].stationuuid, "uuid-1")
    }

    func testRecordPlayMultipleStations() async {
        let station1 = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        let station2 = TestFixtures.makeStation(uuid: "uuid-2", name: "Station 2")

        await service.recordPlay(station: station1)
        await service.recordPlay(station: station2)

        let entries = await service.allEntries()
        XCTAssertEqual(entries.count, 2)
        // Most recent first
        XCTAssertEqual(entries[0].stationuuid, "uuid-2")
        XCTAssertEqual(entries[1].stationuuid, "uuid-1")
    }

    // MARK: - Dedup

    func testDedupWithin30Minutes() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await service.recordPlay(station: station)
        await service.recordPlay(station: station)

        let entries = await service.allEntries()
        XCTAssertEqual(entries.count, 1, "Should dedup same station within 30 minutes")
    }

    func testDedupUpdatesTimestamp() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await service.recordPlay(station: station)

        let entriesBefore = await service.allEntries()
        let firstPlayedAt = entriesBefore[0].playedAt

        // Small delay to ensure different timestamp
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        await service.recordPlay(station: station)

        let entriesAfter = await service.allEntries()
        XCTAssertEqual(entriesAfter.count, 1)
        XCTAssertGreaterThanOrEqual(entriesAfter[0].playedAt, firstPlayedAt)
    }

    func testNoDedupAfter30Minutes() async {
        // Seed an entry with a timestamp 31 minutes ago
        let oldEntry = HistoryEntry(
            stationuuid: "uuid-1",
            name: "Station 1",
            urlResolved: "http://stream.test/resolved",
            codec: "MP3",
            bitrate: 128,
            playedAt: Date().addingTimeInterval(-31 * 60)
        )
        await service.setEntries([oldEntry])

        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await service.recordPlay(station: station)

        let entries = await service.allEntries()
        XCTAssertEqual(entries.count, 2, "Should insert new entry after 30-minute window")
    }

    func testDedupMovesToFront() async {
        let station1 = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        let station2 = TestFixtures.makeStation(uuid: "uuid-2", name: "Station 2")

        await service.recordPlay(station: station1)
        await service.recordPlay(station: station2)
        // Replay station1 — should move to front
        await service.recordPlay(station: station1)

        let entries = await service.allEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].stationuuid, "uuid-1")
        XCTAssertEqual(entries[1].stationuuid, "uuid-2")
    }

    // MARK: - Max Entries

    func testMaxEntries() async {
        for i in 0..<55 {
            let station = TestFixtures.makeStation(uuid: "uuid-\(i)", name: "Station \(i)")
            await service.recordPlay(station: station)
        }

        let entries = await service.allEntries()
        XCTAssertEqual(entries.count, 50, "Should enforce 50-entry limit")
        // Most recent should be first
        XCTAssertEqual(entries[0].stationuuid, "uuid-54")
    }

    // MARK: - Recent Entries

    func testRecentEntriesLimit() async {
        for i in 0..<20 {
            let station = TestFixtures.makeStation(uuid: "uuid-\(i)", name: "Station \(i)")
            await service.recordPlay(station: station)
        }

        let recent = await service.recentEntries(limit: 5)
        XCTAssertEqual(recent.count, 5)
        XCTAssertEqual(recent[0].stationuuid, "uuid-19")
    }

    func testRecentEntriesReturnsAllWhenLessThanLimit() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await service.recordPlay(station: station)

        let recent = await service.recentEntries(limit: 10)
        XCTAssertEqual(recent.count, 1)
    }

    // MARK: - Clear All

    func testClearAll() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await service.recordPlay(station: station)
        let beforeClear = await service.allEntries()
        XCTAssertEqual(beforeClear.count, 1)

        await service.clearAll()
        let afterClear = await service.allEntries()
        XCTAssertEqual(afterClear.count, 0)
    }

    // MARK: - Persistence

    func testPersistenceAcrossInstances() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await service.recordPlay(station: station)

        // Create new service instance with same defaults
        let service2 = HistoryService(defaults: defaults)
        let entries = await service2.allEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].stationuuid, "uuid-1")
    }

    func testEmptyHistoryOnFreshDefaults() async {
        let entries = await service.allEntries()
        XCTAssertTrue(entries.isEmpty)
    }
}
