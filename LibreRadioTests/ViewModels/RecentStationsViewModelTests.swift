import XCTest
@testable import LibreRadio

@MainActor
final class RecentStationsViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private var historyService: HistoryService!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "RecentStationsViewModelTests")!
        defaults.removePersistentDomain(forName: "RecentStationsViewModelTests")
        historyService = HistoryService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "RecentStationsViewModelTests")
    }

    // MARK: - Initial State

    func testInitialState() {
        let vm = RecentStationsViewModel(historyService: historyService)
        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.showClearConfirmation)
    }

    // MARK: - Load

    func testLoadPopulatesEntries() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await historyService.recordPlay(station: station)

        let vm = RecentStationsViewModel(historyService: historyService)
        await vm.load()

        XCTAssertEqual(vm.entries.count, 1)
        XCTAssertEqual(vm.entries[0].stationuuid, "uuid-1")
        XCTAssertFalse(vm.isLoading)
    }

    func testLoadEmptyHistory() async {
        let vm = RecentStationsViewModel(historyService: historyService)
        await vm.load()

        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Refresh

    func testRefreshReloadsData() async {
        let vm = RecentStationsViewModel(historyService: historyService)
        await vm.load()
        XCTAssertTrue(vm.entries.isEmpty)

        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await historyService.recordPlay(station: station)

        await vm.refresh()
        XCTAssertEqual(vm.entries.count, 1)
    }

    // MARK: - Clear All

    func testClearAllRemovesEntries() async {
        let station = TestFixtures.makeStation(uuid: "uuid-1", name: "Station 1")
        await historyService.recordPlay(station: station)

        let vm = RecentStationsViewModel(historyService: historyService)
        await vm.load()
        XCTAssertEqual(vm.entries.count, 1)

        await vm.clearAll()
        XCTAssertTrue(vm.entries.isEmpty)

        // Also cleared from service
        let serviceEntries = await historyService.allEntries()
        XCTAssertTrue(serviceEntries.isEmpty)
    }

    // MARK: - Concurrency Guard

    func testLoadGuardsAgainstConcurrency() async {
        let vm = RecentStationsViewModel(historyService: historyService)
        vm.isLoading = true

        await vm.load()

        // Guard returned early, isLoading still true
        XCTAssertTrue(vm.isLoading)
    }
}
