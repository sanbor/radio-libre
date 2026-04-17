import XCTest
import Foundation

/// Regression tests to prevent re-introducing Mac Catalyst crashes.
///
/// The macOS (Mac Catalyst) build crashed due to two issues:
/// 1. AVRoutePickerView (UIViewRepresentable) triggering a UIKit focus system assertion
/// 2. SwiftUI sheets on Catalyst not inheriting environmentObject from parent views
///
/// These tests verify the source-level guards remain in place.
final class MacCatalystGuardTests: XCTestCase {

    // MARK: - AirPlayButton exclusion guards

    func testAirPlayButtonIsGuardedForMacCatalyst() throws {
        let source = try readSource("LibreRadio/Views/Player/AirPlayButton.swift")
        XCTAssertTrue(
            source.contains("#if !targetEnvironment(macCatalyst)"),
            "AirPlayButton.swift must be wrapped in #if !targetEnvironment(macCatalyst) to prevent UIKit focus system crash on Mac Catalyst"
        )
    }

    func testMiniPlayerViewGuardsAirPlayButton() throws {
        let source = try readSource("LibreRadio/Views/Player/MiniPlayerView.swift")
        XCTAssertTrue(
            source.contains("#if !targetEnvironment(macCatalyst)"),
            "MiniPlayerView.swift must guard AirPlayButton usage with #if !targetEnvironment(macCatalyst)"
        )
    }

    func testPlayerControlsViewGuardsAirPlayButton() throws {
        let source = try readSource("LibreRadio/Views/Player/PlayerControlsView.swift")
        XCTAssertTrue(
            source.contains("#if !targetEnvironment(macCatalyst)"),
            "PlayerControlsView.swift must guard AirPlayButton usage with #if !targetEnvironment(macCatalyst)"
        )
    }

    func testAudioPlayerServiceGuardsRouteDetectorForMacCatalyst() throws {
        let source = try readSource("LibreRadio/Services/AudioPlayerService.swift")
        XCTAssertTrue(
            source.contains("!targetEnvironment(macCatalyst)"),
            "AudioPlayerService.swift must guard route detector setup with !targetEnvironment(macCatalyst)"
        )
    }

    // MARK: - Sheet environment object injection

    func testRootTabViewPassesEnvironmentObjectsToSheet() throws {
        let source = try readSource("LibreRadio/Views/RootTabView.swift")

        // The sheet presenting FullPlayerView must explicitly pass both environment objects.
        // On Mac Catalyst, sheets do NOT inherit environmentObject from parent views.
        XCTAssertTrue(
            source.contains(".environmentObject(playerVM)"),
            "RootTabView must explicitly pass playerVM to FullPlayerView sheet — Catalyst sheets don't inherit environment objects"
        )
        XCTAssertTrue(
            source.contains(".environmentObject(favoritesVM)"),
            "RootTabView must explicitly pass favoritesVM to FullPlayerView sheet — Catalyst sheets don't inherit environment objects"
        )
    }

    // MARK: - MenuBarService setup guard

    func testLibreRadioAppSetsUpMenuBarOnCatalyst() throws {
        let source = try readSource("LibreRadio/App/LibreRadioApp.swift")
        XCTAssertTrue(
            source.contains("MenuBarService.shared.setup"),
            "LibreRadioApp must call MenuBarService.shared.setup on Mac Catalyst for menu bar player"
        )
    }

    // MARK: - Helpers

    /// Locates and reads a source file relative to the project root.
    ///
    /// Uses `#filePath` to derive the project root: this test file lives at
    /// `LibreRadioTests/Views/MacCatalystGuardTests.swift`, so the project root
    /// is three directories up.
    private func readSource(_ relativePath: String, testFile: StaticString = #filePath) throws -> String {
        // This file: <project-root>/LibreRadioTests/Views/MacCatalystGuardTests.swift
        // Project root is 3 levels up
        let thisFile = URL(fileURLWithPath: "\(testFile)")
        let projectRoot = thisFile
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // LibreRadioTests/
            .deletingLastPathComponent()  // project root

        let sourceURL = projectRoot.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Could not locate source file \(relativePath) at \(sourceURL.path) — source-level guard test skipped")
        }
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
