import XCTest
import SwiftUI
@testable import LibreRadio

@MainActor
final class AboutViewTests: XCTestCase {

    // MARK: - View Instantiation

    func testAboutViewCanBeInstantiated() {
        // AboutView is fully static — no environment objects required.
        _ = AboutView()
    }

    // MARK: - Version String Formatting

    func testVersionStringFormatsBothValues() {
        XCTAssertEqual(
            aboutVersionString(shortVersion: "1.0.0", build: "1"),
            "1.0.0 (1)"
        )
    }

    func testVersionStringFormatsMultiDigitBuild() {
        XCTAssertEqual(
            aboutVersionString(shortVersion: "2.3.4", build: "42"),
            "2.3.4 (42)"
        )
    }

    func testVersionStringFallsBackToShortVersionOnly() {
        XCTAssertEqual(
            aboutVersionString(shortVersion: "1.0.0", build: nil),
            "1.0.0"
        )
    }

    func testVersionStringReturnsDashWhenShortVersionMissing() {
        // If CFBundleShortVersionString is unavailable, we show "—" regardless of build.
        XCTAssertEqual(
            aboutVersionString(shortVersion: nil, build: "1"),
            "—"
        )
    }

    func testVersionStringReturnsDashWhenBothMissing() {
        XCTAssertEqual(
            aboutVersionString(shortVersion: nil, build: nil),
            "—"
        )
    }
}
