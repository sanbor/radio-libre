import XCTest
@testable import RadioLibre

@MainActor
final class NetworkMonitorServiceTests: XCTestCase {

    func testInitialStateIsConnected() {
        let service = NetworkMonitorService()
        XCTAssertTrue(service.isConnected)
    }

    func testIsObservableObject() {
        let service = NetworkMonitorService()
        // Verify it conforms to ObservableObject by using it
        let _ = service.objectWillChange
    }
}
