import Foundation
import ObjectiveC.runtime

#if targetEnvironment(macCatalyst)
import UIKit
#endif

// MARK: - Menu Bar State (platform-agnostic, testable on all platforms)

struct MenuBarState {
    struct Favorite {
        let uuid: String
        let name: String
    }

    var stationName: String?
    var trackInfo: String?
    var errorMessage: String?
    var isPlaying: Bool
    var isLoading: Bool
    var isPaused: Bool
    var isError: Bool
    var volume: Float
    var favorites: [Favorite]

    var playPauseTitle: String {
        isPlaying ? "Pause" : "Play"
    }

    var playPauseEnabled: Bool {
        !isLoading
    }

    var stopEnabled: Bool {
        isPlaying || isLoading || isPaused || isError
    }

    /// Returns the index of the closest volume preset (0=Mute, 1=25%, 2=50%, 3=75%, 4=100%).
    var volumePresetIndex: Int {
        let presets: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        var closestIndex = 0
        var closestDist = Float.greatestFiniteMagnitude
        for (i, preset) in presets.enumerated() {
            let dist = abs(volume - preset)
            if dist < closestDist {
                closestDist = dist
                closestIndex = i
            }
        }
        return closestIndex
    }
}

enum MenuBarStateBuilder {
    @MainActor
    static func compute(
        playerVM: PlayerViewModel?,
        favoritesVM: FavoritesViewModel?
    ) -> MenuBarState {
        let audioService = playerVM?.audioService
        return compute(
            playbackState: audioService?.state,
            trackTitle: audioService?.currentTrackTitle,
            artist: audioService?.currentArtist,
            volume: audioService?.volume ?? 1.0,
            favorites: favoritesVM?.favorites ?? []
        )
    }

    static func compute(
        playbackState: AudioPlayerService.PlaybackState?,
        trackTitle: String?,
        artist: String?,
        volume: Float,
        favorites: [FavoriteStation]
    ) -> MenuBarState {
        let stationName: String?
        let isPlaying: Bool
        let isLoading: Bool
        let isPaused: Bool
        let isError: Bool
        let errorMessage: String?

        switch playbackState {
        case .playing(let station):
            stationName = station.name
            isPlaying = true
            isLoading = false
            isPaused = false
            isError = false
            errorMessage = nil
        case .loading(let station):
            stationName = station.name
            isPlaying = false
            isLoading = true
            isPaused = false
            isError = false
            errorMessage = nil
        case .paused(let station):
            stationName = station.name
            isPlaying = false
            isLoading = false
            isPaused = true
            isError = false
            errorMessage = nil
        case .error(let station, let message):
            stationName = station.name
            isPlaying = false
            isLoading = false
            isPaused = false
            isError = true
            errorMessage = message
        case .idle, .none:
            stationName = nil
            isPlaying = false
            isLoading = false
            isPaused = false
            isError = false
            errorMessage = nil
        }

        var trackInfo: String?
        if let title = trackTitle {
            if let artist = artist {
                trackInfo = "\(artist) — \(title)"
            } else {
                trackInfo = title
            }
        }

        let mappedFavorites: [MenuBarState.Favorite] = favorites.map {
            MenuBarState.Favorite(uuid: $0.stationuuid, name: $0.name)
        }

        return MenuBarState(
            stationName: stationName,
            trackInfo: trackInfo,
            errorMessage: errorMessage,
            isPlaying: isPlaying,
            isLoading: isLoading,
            isPaused: isPaused,
            isError: isError,
            volume: volume,
            favorites: mappedFavorites
        )
    }
}

// MARK: - AppKit Runtime Bridge (Mac Catalyst only)

#if targetEnvironment(macCatalyst)

/// Thin runtime wrappers for AppKit classes unavailable at compile time in Catalyst.
/// Uses NSClassFromString + typed @convention(c) function pointers.
/// Internal (not `private`) so tests with `@testable import LibreRadio` can
/// exercise each runtime lookup — these are string-typed and fail only at runtime.
enum AppKitBridge {

    // MARK: NSStatusBar / NSStatusItem

    static func systemStatusBar() -> NSObject? {
        guard let cls = NSClassFromString("NSStatusBar") else { return nil }
        let sel = NSSelectorFromString("systemStatusBar")
        guard let metaclass = object_getClass(cls),
              let method = class_getMethodImplementation(metaclass, sel) else { return nil }
        typealias Fn = @convention(c) (AnyClass, Selector) -> AnyObject?
        let imp = unsafeBitCast(method, to: Fn.self)
        return imp(cls, sel) as? NSObject
    }

    /// Creates an NSStatusItem with variable width (NSVariableStatusItemLength = -1).
    static func createStatusItem(from bar: NSObject) -> NSObject? {
        let sel = NSSelectorFromString("statusItemWithLength:")
        guard let method = bar.method(for: sel) else { return nil }
        typealias Fn = @convention(c) (NSObject, Selector, CGFloat) -> NSObject
        let imp = unsafeBitCast(method, to: Fn.self)
        return imp(bar, sel, CGFloat(-1))
    }

    // MARK: NSImage

    /// Creates an NSImage from an SF Symbol name.
    static func systemImage(name: String) -> NSObject? {
        guard let cls = NSClassFromString("NSImage") else { return nil }
        let sel = NSSelectorFromString("imageWithSystemSymbolName:accessibilityDescription:")
        guard let metaclass = object_getClass(cls),
              let method = class_getMethodImplementation(metaclass, sel) else { return nil }
        typealias Fn = @convention(c) (AnyObject, Selector, NSString, NSString?) -> AnyObject?
        let imp = unsafeBitCast(method, to: Fn.self)
        return imp(cls, sel, name as NSString, nil) as? NSObject
    }

    // MARK: NSMenu

    static func createMenu(title: String = "") -> NSObject? {
        guard let cls = NSClassFromString("NSMenu"),
              let allocated = class_createInstance(cls, 0) as? NSObject else { return nil }
        let sel = NSSelectorFromString("initWithTitle:")
        guard let method = allocated.method(for: sel) else { return nil }
        typealias Fn = @convention(c) (NSObject, Selector, NSString) -> NSObject
        let imp = unsafeBitCast(method, to: Fn.self)
        return imp(allocated, sel, title as NSString)
    }

    static func removeAllItems(from menu: NSObject) {
        menu.perform(NSSelectorFromString("removeAllItems"))
    }

    static func addItem(_ item: NSObject, to menu: NSObject) {
        menu.perform(NSSelectorFromString("addItem:"), with: item)
    }

    // MARK: NSMenuItem

    static func createMenuItem(
        title: String,
        action: Selector?,
        keyEquivalent: String = "",
        target: AnyObject? = nil,
        tag: Int = 0
    ) -> NSObject? {
        guard let cls = NSClassFromString("NSMenuItem"),
              let allocated = class_createInstance(cls, 0) as? NSObject else { return nil }
        let sel = NSSelectorFromString("initWithTitle:action:keyEquivalent:")
        guard let method = allocated.method(for: sel) else { return nil }
        typealias Fn = @convention(c) (NSObject, Selector, NSString, Selector?, NSString) -> NSObject
        let imp = unsafeBitCast(method, to: Fn.self)
        let item = imp(allocated, sel, title as NSString, action, keyEquivalent as NSString)
        if let target {
            item.setValue(target, forKey: "target")
        }
        item.setValue(tag, forKey: "tag")
        return item
    }

    static func separatorItem() -> NSObject? {
        guard let cls = NSClassFromString("NSMenuItem") else { return nil }
        let sel = NSSelectorFromString("separatorItem")
        guard let metaclass = object_getClass(cls),
              let method = class_getMethodImplementation(metaclass, sel) else { return nil }
        typealias Fn = @convention(c) (AnyClass, Selector) -> AnyObject?
        let imp = unsafeBitCast(method, to: Fn.self)
        return imp(cls, sel) as? NSObject
    }

    static func setEnabled(_ enabled: Bool, on item: NSObject) {
        item.setValue(enabled, forKey: "enabled")
    }

    static func setState(_ state: Int, on item: NSObject) {
        item.setValue(state, forKey: "state")
    }

    static func setSubmenu(_ submenu: NSObject, on item: NSObject) {
        item.setValue(submenu, forKey: "submenu")
    }

    // MARK: NSApplication

    static func activateApp() {
        guard let cls = NSClassFromString("NSApplication"),
              let nsApp = cls.value(forKey: "sharedApplication") as? NSObject else { return }
        let sel = NSSelectorFromString("activateIgnoringOtherApps:")
        guard let method = nsApp.method(for: sel) else { return }
        typealias Fn = @convention(c) (NSObject, Selector, Bool) -> Void
        let imp = unsafeBitCast(method, to: Fn.self)
        imp(nsApp, sel, true)
    }
}

// MARK: - MenuBarService

@MainActor
final class MenuBarService: NSObject {
    static let shared = MenuBarService()

    private var statusItem: NSObject?
    private var menu: NSObject?
    // Weak refs are defensive — both VMs live for the app lifetime (static singleton
    // and @StateObject respectively) but we avoid creating a retain cycle on principle.
    private weak var playerVM: PlayerViewModel?
    private weak var favoritesVM: FavoritesViewModel?
    private var isSetUp = false

    /// Exposed for testing — avoids brittle Mirror-based private access in bridge tests.
    var attachedMenuForTesting: NSObject? { menu }

    func setup(playerVM: PlayerViewModel, favoritesVM: FavoritesViewModel) {
        guard !isSetUp else { return }
        isSetUp = true
        self.playerVM = playerVM
        self.favoritesVM = favoritesVM

        guard let bar = AppKitBridge.systemStatusBar(),
              let item = AppKitBridge.createStatusItem(from: bar) else { return }
        statusItem = item

        // Set button icon
        if let button = item.value(forKey: "button") as? NSObject,
           let image = AppKitBridge.systemImage(name: "antenna.radiowaves.left.and.right") {
            button.setValue(image, forKey: "image")
        }

        // Create menu and set self as delegate
        guard let menu = AppKitBridge.createMenu() else { return }
        self.menu = menu
        menu.setValue(false, forKey: "autoenablesItems")
        menu.setValue(self, forKey: "delegate")
        item.setValue(menu, forKey: "menu")

        // Eagerly populate the menu with the initial state. This guarantees the
        // menu is never empty when clicked — the delegate's menuNeedsUpdate:
        // rebuilds later to refresh live state.
        rebuildMenu()
    }

    // MARK: - NSMenuDelegate (informal, dispatched via ObjC runtime)

    @objc func menuNeedsUpdate(_ menu: AnyObject) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu else { return }
        AppKitBridge.removeAllItems(from: menu)

        let state = MenuBarStateBuilder.compute(playerVM: playerVM, favoritesVM: favoritesVM)
        buildMenu(into: menu, from: state)
    }

    // MARK: - Menu Construction

    private func buildMenu(into menu: NSObject, from state: MenuBarState) {
        // Station info
        let stationTitle = state.stationName ?? "No Station Playing"
        if let item = AppKitBridge.createMenuItem(title: stationTitle, action: nil) {
            AppKitBridge.setEnabled(false, on: item)
            AppKitBridge.addItem(item, to: menu)
        }

        // Track info (if available)
        if let trackInfo = state.trackInfo,
           let item = AppKitBridge.createMenuItem(title: "♫ \(trackInfo)", action: nil) {
            AppKitBridge.setEnabled(false, on: item)
            AppKitBridge.addItem(item, to: menu)
        }

        // Loading indicator
        if state.isLoading,
           let item = AppKitBridge.createMenuItem(title: "Connecting…", action: nil) {
            AppKitBridge.setEnabled(false, on: item)
            AppKitBridge.addItem(item, to: menu)
        }

        // Error indicator
        if let errorMessage = state.errorMessage,
           let item = AppKitBridge.createMenuItem(title: "Error: \(errorMessage)", action: nil) {
            AppKitBridge.setEnabled(false, on: item)
            AppKitBridge.addItem(item, to: menu)
        }

        // Separator
        if let sep = AppKitBridge.separatorItem() {
            AppKitBridge.addItem(sep, to: menu)
        }

        // Play/Pause
        if let item = AppKitBridge.createMenuItem(
            title: state.playPauseTitle,
            action: #selector(togglePlayPause),
            target: self
        ) {
            AppKitBridge.setEnabled(state.playPauseEnabled, on: item)
            AppKitBridge.addItem(item, to: menu)
        }

        // Stop
        if let item = AppKitBridge.createMenuItem(
            title: "Stop",
            action: #selector(stopPlayback),
            target: self
        ) {
            AppKitBridge.setEnabled(state.stopEnabled, on: item)
            AppKitBridge.addItem(item, to: menu)
        }

        // Separator
        if let sep = AppKitBridge.separatorItem() {
            AppKitBridge.addItem(sep, to: menu)
        }

        // Favorites submenu
        buildFavoritesSubmenu(into: menu, favorites: state.favorites)

        // Separator
        if let sep = AppKitBridge.separatorItem() {
            AppKitBridge.addItem(sep, to: menu)
        }

        // Volume submenu
        buildVolumeSubmenu(into: menu, currentPreset: state.volumePresetIndex)

        // Separator
        if let sep = AppKitBridge.separatorItem() {
            AppKitBridge.addItem(sep, to: menu)
        }

        // Show LibreRadio
        if let item = AppKitBridge.createMenuItem(
            title: "Show LibreRadio",
            action: #selector(showMainWindow),
            target: self
        ) {
            AppKitBridge.addItem(item, to: menu)
        }
    }

    private func buildFavoritesSubmenu(into menu: NSObject, favorites: [MenuBarState.Favorite]) {
        guard let parentItem = AppKitBridge.createMenuItem(title: "Favorites", action: nil),
              let submenu = AppKitBridge.createMenu(title: "Favorites") else { return }

        submenu.setValue(false, forKey: "autoenablesItems")

        if favorites.isEmpty {
            if let emptyItem = AppKitBridge.createMenuItem(title: "No Favorites", action: nil) {
                AppKitBridge.setEnabled(false, on: emptyItem)
                AppKitBridge.addItem(emptyItem, to: submenu)
            }
        } else {
            for (index, fav) in favorites.enumerated() {
                if let item = AppKitBridge.createMenuItem(
                    title: fav.name,
                    action: #selector(playFavorite(_:)),
                    target: self,
                    tag: index
                ) {
                    // Mark currently playing favorite
                    if let currentUUID = playerVM?.currentStation?.stationuuid,
                       currentUUID == fav.uuid {
                        AppKitBridge.setState(1, on: item) // NSControlStateValueOn
                    }
                    AppKitBridge.addItem(item, to: submenu)
                }
            }
        }

        AppKitBridge.setSubmenu(submenu, on: parentItem)
        AppKitBridge.addItem(parentItem, to: menu)
    }

    private func buildVolumeSubmenu(into menu: NSObject, currentPreset: Int) {
        guard let parentItem = AppKitBridge.createMenuItem(title: "Volume", action: nil),
              let submenu = AppKitBridge.createMenu(title: "Volume") else { return }

        submenu.setValue(false, forKey: "autoenablesItems")

        let presets = ["Mute", "25%", "50%", "75%", "100%"]
        for (index, label) in presets.enumerated() {
            if let item = AppKitBridge.createMenuItem(
                title: label,
                action: #selector(setVolume(_:)),
                target: self,
                tag: index
            ) {
                if index == currentPreset {
                    AppKitBridge.setState(1, on: item)
                }
                AppKitBridge.addItem(item, to: submenu)
            }
        }

        AppKitBridge.setSubmenu(submenu, on: parentItem)
        AppKitBridge.addItem(parentItem, to: menu)
    }

    // MARK: - Actions

    @objc private func togglePlayPause() {
        playerVM?.togglePlayPause()
    }

    @objc private func stopPlayback() {
        playerVM?.stop()
    }

    @objc private func playFavorite(_ sender: AnyObject) {
        guard let tag = sender.value(forKey: "tag") as? Int,
              let favorites = favoritesVM?.favorites,
              favorites.indices.contains(tag) else { return }
        let station = favorites[tag].toStationDTO()
        let context = PlaybackContext(source: .favorites, stations: favorites.map { $0.toStationDTO() })
        playerVM?.play(station: station, context: context)
    }

    @objc private func setVolume(_ sender: AnyObject) {
        guard let tag = sender.value(forKey: "tag") as? Int else { return }
        let presetValues: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        guard presetValues.indices.contains(tag) else { return }
        playerVM?.audioService.volume = presetValues[tag]
    }

    @objc private func showMainWindow() {
        AppKitBridge.activateApp()
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil, errorHandler: nil)
    }
}

#endif
