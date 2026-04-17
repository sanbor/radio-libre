# Changelog

## 2026-04-15 — Add macOS menu bar player (Mac Catalyst)

**Prompt:** `/implement for macOS version implement a menu bar player`

**Changes:**
- `LibreRadio/Services/MenuBarService.swift` (new, ~430 lines): adds an `NSStatusItem` with an antenna SF Symbol (`antenna.radiowaves.left.and.right`) to the macOS menu bar on Mac Catalyst. Clicking opens a dropdown `NSMenu` rebuilt on every open via `menuNeedsUpdate:`. Menu shows station info, track info (when metadata available), Play/Pause, Stop, a Favorites submenu (with checkmark on currently-playing favorite), a Volume submenu (five presets: Mute/25%/50%/75%/100%, closest preset checkmarked), and "Show LibreRadio" which activates the app. All AppKit access is via the Objective-C runtime (`NSClassFromString`, `class_createInstance`, typed `@convention(c)` function pointers, KVC) because `import AppKit` is unavailable in Catalyst.
- `LibreRadio/Services/MenuBarService.swift` exposes `struct MenuBarState` and `enum MenuBarStateBuilder` (both platform-agnostic) so the menu-state derivation logic is unit-testable on iOS Simulator without an AppKit runtime.
- `LibreRadio/App/LibreRadioApp.swift`: calls `MenuBarService.shared.setup(playerVM:favoritesVM:)` inside the root `.task` block, guarded by `#if targetEnvironment(macCatalyst)`. Setup is idempotent via an `isSetUp` flag.
- `LibreRadioTests/Services/MenuBarServiceTests.swift` (new): 16 tests covering idle/playing/loading/paused state transitions, volume preset snap-to-closest (including the boundary cases 0.12→Mute and 0.13→25%), favorites population/empty, track info formatting with and without artist, and builder behavior with nil view models.
- `LibreRadioTests/Services/MenuBarBridgeTests.swift` (new): 11 runtime tests gated by `#if targetEnvironment(macCatalyst)` that exercise every `AppKitBridge` method (systemStatusBar, createStatusItem, createMenu, createMenuItem, separatorItem, systemImage, setEnabled/setState/setSubmenu KVC, addItem/removeAllItems) plus an integration smoke test (`testMenuBarServiceSetupProducesNonEmptyMenu`) that calls `MenuBarService.shared.setup()` and verifies the attached menu has items after rebuild. Runs via `xcodebuild -destination 'platform=macOS,variant=Mac Catalyst' test`.
- `LibreRadioTests/Views/MacCatalystGuardTests.swift`: added `testLibreRadioAppSetsUpMenuBarOnCatalyst` regression test verifying the setup call exists in `LibreRadioApp.swift`.

**Bugs caught by the new Mac Catalyst runtime tests (and fixed):**
- `systemStatusBar()` initially used `cls.value(forKeyPath: "system")` — the Swift rename, not the ObjC selector. At runtime this raised `NSUnknownKeyException: [NSStatusBar ... valueForUndefinedKey:]: this class is not key value coding-compliant for the key system`. Fixed to call `+[NSStatusBar systemStatusBar]` via `class_getMethodImplementation` on the metaclass.
- `setEnabled(_:on:)` used `setValue(enabled, forKey: "isEnabled")` on NSMenuItem. The property is `@property(getter=isEnabled) BOOL enabled`, so the KVC setter key must be `"enabled"` (maps to `setEnabled:`), not `"isEnabled"` (which would look for the non-existent `setIsEnabled:`). Fixed.
- Clicking the status icon did nothing on first run because the menu was only built lazily via the `menuNeedsUpdate:` delegate callback, and the callback wasn't firing reliably on first click. Changed `MenuBarService.setup()` to eagerly populate the menu with initial state immediately after creating it — the delegate rebuild still fires for live updates.
- `SPEC.md`: added a detailed menu bar layout specification under the macOS (Catalyst or native) section.
- `PLAN.md`: marked Phase 9 (macOS menu bar) as done, added a full "Menu Bar Player (Mac Catalyst)" section documenting architecture, runtime patterns, NSMenu-vs-NSPopover decision, and implementation notes (isolation traps, `cls.alloc()` typecheck failure on Catalyst, separator item metaclass pattern, tag-0-ambiguity behavior).

**Design decisions:**
- **NSMenu over NSPopover** — the spec mentioned "popover with mini player," but NSPopover requires embedding SwiftUI via `NSHostingView` which needs significantly more AppKit bridging. NSMenu gives the same functionality with far less surface area. SwiftUI-hosted popover is a v2 enhancement.
- **Runtime AppKit access, no plugin bundle** — Apple's official recommendation for Catalyst+AppKit integration is a separate AppKit plugin bundle with NotificationCenter IPC. We chose direct runtime access instead: simpler (single file), no XcodeGen changes, direct access to `PlayerViewModel.shared` and `FavoritesViewModel`.
- **Menu rebuilt on every open** — no state-change observation. `menuNeedsUpdate:` tears down and reconstructs ~15–20 menu items on each click. Avoids cache-invalidation bugs; negligible cost.

**Verification:**
- `xcodegen generate` regenerated the project.
- iOS Simulator build + full test suite (465 tests) pass with no failures.
- Mac Catalyst build succeeds.

## 2026-04-11 — Add About screen with radio-browser.info attribution

**Prompt:** `/implement add a more section where states libreradio uses information provided by radio-browser.info and radio-browser.info data license. [Image #3] [Image #4]`

**Changes:**
- `LibreRadio/Views/About/AboutView.swift` (new): static `NavigationStack` sheet with six sections — banner (app name + version + tagline), About LibreRadio, Data Source (with link), Data License (verbatim public-domain declaration from radio-browser.info's homepage, rendered as a styled blockquote with attribution footer), Attribution (radio-browser.info donation/contribution + RadioDroid + GNU meditating Gnu icon credits), and LibreRadio (GPL-3.0 + GitHub/Issues/Contact links). Version string is computed via a file-level free function `aboutVersionString(shortVersion:build:)` so its branches are unit-testable without touching `Bundle.main`.
- `LibreRadio/Views/Home/HomeView.swift`: added an `info.circle` toolbar button (top-trailing) with accessibility label "About LibreRadio" that presents `AboutView` as a sheet via `@State private var showAbout`. No other changes to HomeView.
- `LibreRadioTests/Views/AboutViewTests.swift` (new): smoke test for `AboutView` instantiation plus five `aboutVersionString` branch tests (both present, multi-digit build, short-version only, short-version missing, both missing).
- `SPEC.md`: added an **About** subsection under the main app structure sections, documenting the info button placement and sheet contents. Referenced from the Home section.
- `PLAN.md`: added `LibreRadio/Views/About/AboutView.swift` to the file-structure tree, appended a Phase 6 line item for the About screen, and added an implementation notes block capturing the placement rationale (no 6th tab), the README-as-source-of-truth rule, and the SourceKit false-positive diagnostics for macCatalyst-available APIs.

**Design decisions:**
- **No 6th tab** — the iOS tab bar already holds 5 tabs, which is the maximum before iOS auto-collapses into a "More" tab. An info button on the Home tab (the default landing screen) is maximally discoverable while staying out of the primary navigation.
- **Verbatim quote** — the radio-browser.info public-domain declaration is quoted exactly as published on the homepage so attribution is faithful to the source.
- **Static view, no ViewModel** — the About screen has no dynamic state, no network calls, and no environment-object dependencies.

**Verification:**
- `xcodegen generate` regenerated the project; `xcodebuild ... build` completed with only benign stale-artifact warnings.
- Full test suite: **447 tests passed, 0 failures** (6 new `AboutViewTests` included).

## 2026-04-10 — Log dropped metadata items with unrecognized identifiers

**Prompt:** `/implement add a debug log when MetadataOutputHandler drops an item with an unrecognized identifier`

**Changes:**
- `LibreRadio/Services/AudioPlayerService.swift`: `MetadataOutputHandler` now emits an `os.Logger` `.debug` message (subsystem `com.libreradio`, category `MetadataOutputHandler`) for every timed metadata item whose identifier is non-nil but not in `titleIdentifiers`. Items with `nil` identifiers are not logged (AVFoundation no-op case). The log closure is injected via a new `MetadataOutputHandler(logUnrecognizedIdentifier:)` initializer so tests can capture identifiers directly instead of scraping the unified logging system; the default binds to a `static let logger` to avoid allocating a `Logger` per dropped item
- `LibreRadioTests/Services/AudioPlayerServiceTests.swift`: added `testMetadataHandlerLogsUnrecognizedIdentifier` (drives a synthetic `.commonIdentifierAlbumName` item through the delegate and asserts the log captured the identifier and the track title/artist remain nil) and `testMetadataHandlerDoesNotLogRecognizedIdentifier` (ICY item is parsed normally and the log is not invoked). Added a file-private `CapturedIdentifiers` reference-type helper to support the assertions
- `PLAN.md`: added a Phase 2 implementation note documenting the debug-log rationale and the injectable-closure testing pattern

## 2026-04-10 — Restore ICY artist/song display from radio streams

**Prompt:** `/implement previously current tracks were shown. The functionality stopped worked at some point. Show ICY name of artist and song again.`

**Changes:**
- Fixed regression introduced on 2026-03-26 (commit `aa62ee9` — "Fix deprecated timedMetadata KVO and Sendable warnings") where ICY stream metadata stopped being surfaced in the mini player, full player, and lock screen
- Root cause: when switching from `timedMetadata` KVO to `AVPlayerItemMetadataOutput`, the filter was changed from `metadata.commonKey == .commonKeyTitle` (abstract common-mapped key) to `item.identifier == .commonIdentifierTitle` (native identifier). ICY/Shoutcast/Icecast items arrive with `AVMetadataIdentifier.icyMetadataStreamTitle`, so every ICY title was silently dropped
- `LibreRadio/Services/AudioPlayerService.swift`: `MetadataOutputHandler` now filters against a `titleIdentifiers` set containing both `.commonIdentifierTitle` and `.icyMetadataStreamTitle`; made the handler and its identifier set internal so tests can drive them directly
- `LibreRadioTests/Services/AudioPlayerServiceTests.swift`: added two regression tests — one asserts the identifier set contains both known title identifiers, the other feeds a synthetic `AVMutableMetadataItem(.icyMetadataStreamTitle)` through the delegate and verifies `currentArtist`/`currentTrackTitle` are populated end-to-end
- `PLAN.md`: documented the identifier-vs-commonKey trap in the Phase 2 implementation notes so the same mistake isn't repeated

## 2026-04-07 — Fix macOS crash when clicking Now Playing section

**Prompt:** `/implement the macos version breaks when clicking the playing now section. check @dump.txt for the stacktrace`

**Changes:**
- Fixed Mac Catalyst crash caused by `AVRoutePickerView` triggering a UIKit focus system assertion failure (`_UIFocusContainerGuideFallbackItemsContainer`)
- Wrapped `AirPlayButton.swift` in `#if !targetEnvironment(macCatalyst)` to exclude the `AVRoutePickerView` wrapper on Mac Catalyst
- Guarded AirPlay button usage in `MiniPlayerView.swift` and `PlayerControlsView.swift` with the same compile-time check
- Skipped `AVRouteDetector` setup on Mac Catalyst in `AudioPlayerService.swift` since the AirPlay button is hidden
- Fixed second crash: explicitly pass `environmentObject` to `FullPlayerView` sheet in `RootTabView` — on Mac Catalyst, sheets don't inherit environment objects from parent views
- macOS handles audio routing via system menu bar / Control Center, so in-app route picker is unnecessary
- Added `MacCatalystGuardTests` (5 tests): source-level regression tests verifying `#if !targetEnvironment(macCatalyst)` guards and explicit environment object injection remain in place
- Added `RootTabViewTests` (5 tests): view instantiation tests for `RootTabView`, `FullPlayerView`, `MiniPlayerView`, and `PlayerControlsView`

## 2026-04-04 — macOS release workflow on tag publish

**Prompt:** `/implement release macos version on github when publishing a tag`

**Changes:**
- Created `.github/workflows/release.yml` — on `v*` tag push, builds Mac Catalyst Release and creates a GitHub Release with `LibreRadio-macOS.zip`
- Enabled Mac Catalyst in `project.yml` by switching both targets from `platform: iOS` to `supportedDestinations: [iOS, macCatalyst]`
- Wrapped `CarPlaySceneDelegate.swift` in `#if canImport(CarPlay)` guard (CarPlay unavailable on Mac Catalyst)
- Updated SPEC.md and PLAN.md with CI/CD documentation

## 2026-03-29 — Fix landscape spacing: search bar overlap and mini player coverage

**Prompt:** `/implement the toggle for sort works great. The only detail is too much white space when the phone is in landscape position / when sorting by name in landscape mode the top item is covered by the search bar, the bottom item is covered by the playing now section`

**Changes:**
- Flat lists (clicks sort): removed landscape top spacer entirely — `.searchable(.navigationBarDrawer)` provides sufficient automatic insets
- Alphabetical lists (name sort): set landscape top spacer to 28pt so the first alphabet index letter is fully visible below the search bar
- Increased landscape bottom padding from 80pt to 160pt to fully clear the floating mini player
- Portrait spacing unchanged (sort picker header + 80pt bottom padding)
- Applied to all 4 browse views: `StationListView`, `CountryListView`, `LanguageListView`, `TagListView`

## 2026-03-29 — Fix sort picker width inconsistency between sort modes

**Prompt:** `/implement [Image #14] [Image #15] when clicking sort by name the width of the toggle changes`

**Changes:**
- Moved `sortPicker` out of `alphabeticalList`/`flatList` list rows and into the parent computed property (`countryList`, `languageList`, `tagList`, `stationList`) as a `VStack(spacing: 0)` header
- Picker is now above the `List` and outside `AlphabetIndexView`'s `.safeAreaInset(edge: .trailing)` scope — always full-width regardless of sort mode
- Removed `.listRowBackground(Color.clear)` and `.listRowSeparator(.hidden)` from `sortPicker` (no longer a list row); added `.padding(.horizontal, 16).padding(.vertical, 8)` for consistent alignment
- In both `alphabeticalList` and `flatList`: the `if/else` sort picker block is replaced with landscape-only 56pt `Color.clear` spacer (portrait picker is now the VStack header)
- Applied to `CountryListView`, `LanguageListView`, `TagListView`, `StationListView`

## 2026-03-29 — Fix large gap when sorting by name in landscape

**Prompt:** `/implement [Image #11] when sorting by name there is a large gap`

**Changes:**
- Replaced the invisible `sortPicker` spacer row (used in landscape to prevent content from hiding behind the search bar) with an explicit `Color.clear.frame(height: 56).listRowInsets(EdgeInsets())` spacer
- Root cause: in iOS 26, `Picker` with `.pickerStyle(.segmented)` renders ~80–100pt tall (vs ~48pt in earlier iOS), making the transparent spacer create a visually obvious empty region
- The 56pt explicit spacer is just enough to push section headers below the search drawer (~6pt visible gap), eliminating the large blank area
- Applied to `alphabeticalList` and `flatList` in `CountryListView`, `LanguageListView`, `TagListView`, `StationListView`

## 2026-03-28 — Fix first country unclickable and sort toggle double-edge in landscape

**Prompt:** `/implement [Image #10] the first country can't be clicked and there is an artifact in the edges of the sort toggle (looks like double edges)`

**Changes:**
- Added `@Environment(\.verticalSizeClass)` to all four browse views
- Portrait: sort picker restored as first list row (original behavior, spacing below search bar preserved)
- Landscape (`verticalSizeClass == .compact`): sort picker row is kept but rendered invisible (`.opacity(0)`, `.disabled`, `.accessibilityHidden`) — maintains the spacing buffer that prevents the first country row from being covered by the search bar
- Landscape: added `sortMenu` — a compact `Menu { Picker }` toolbar button with an `arrow.up.arrow.down` icon — replacing the segmented picker in the toolbar, which caused a double-edge artifact from iOS 26's glass pill container wrapping around the segmented control's own border

## 2026-03-28 — Fix sort toggle inaccessible in landscape mode

**Prompt:** `/implement [Image #9] when the phone is in landscape I can't toggle between name and click sort modes`

**Changes:**
- Moved `sortPicker` from first `List` row to `ToolbarItem(placement: .navigationBarTrailing)` in `CountryListView`, `LanguageListView`, `TagListView`, and `StationListView`
- Root cause: in landscape mode, `searchable(placement: .navigationBarDrawer(displayMode: .always))` causes the first list row to render behind the navigation bar chrome; the segmented control segments were visible but untappable
- Removed list-specific modifiers (`.listRowBackground`, `.listRowSeparator`) from `sortPicker` since it no longer lives inside a `List`
- Sort toggle is now always accessible in both portrait and landscape from the navigation bar trailing area

## 2026-03-28 — Always-visible search bar and browse UX improvements

**Prompt:** `/implement [Image #5] sometimes the top search bar is not shown when entering a browse section, make it always visible`

**Changes:**
- Added `placement: .navigationBarDrawer(displayMode: .always)` to `.searchable()` in `CountryListView`, `LanguageListView`, `TagListView`, and `StationListView` — search bar is now pinned below the navigation title at all times
- Added `.navigationBarTitleDisplayMode(.inline)` to all 4 list views — compact nav bar keeps the sort picker row consistently accessible in both portrait and landscape
- `BrowseView` now owns a single `BrowseViewModel` shared across Countries, Languages, and Tags via `@EnvironmentObject` — switching between sections no longer re-fetches data
- Replaced `onChange(of: searchText)` with a 300 ms debounced `task(id:)` in `StationListView` — `fetchAllIfNeeded` is no longer triggered on every keystroke

## 2026-03-26 — Default antenna artwork on lock screen

**Prompt:** `/implement show a default radio antenna artwork on lock screen when station has no favicon`

**Changes:**
- `NowPlayingService.updateNowPlaying()` now renders a 300×300 placeholder image (antenna SF Symbol on `systemGray6` background) and sets it as artwork immediately on every station switch
- Real favicon is fetched asynchronously and replaces the placeholder when available; stations without a favicon retain the placeholder
- Extracted `setArtwork(_:)` and `defaultPlaceholderImage()` private helpers to reduce duplication
- Added 2 tests: placeholder artwork is set for faviconless stations, stale artwork is replaced with placeholder
- Updated SPEC.md and PLAN.md to document the placeholder artwork behavior

## 2026-03-26 — Fix Xcode deprecation and Sendable warnings

**Prompt:** `/implement fix Xcode warnings: timedMetadata deprecated, stringValue deprecated, non-Sendable function conversion`

**Changes:**
- Replaced deprecated `timedMetadata` KVO observation in `AudioPlayerService` with `AVPlayerItemMetadataOutput` delegate pattern
- Created private `MetadataOutputHandler` class (NSObject subclass) to conform to `AVPlayerItemMetadataOutputPushDelegate`
- Replaced deprecated synchronous `stringValue` with `await item.load(.stringValue)` and `commonKey` with `item.identifier == .commonIdentifierTitle`
- Fixed `ServerDiscoveryService` Sendable warning by wrapping bare function reference in a sendable closure literal
- Zero warnings from both files, all 418 tests pass

## 2026-03-26 — Remove widget extension and Live Activity

**Changes:**
- Removed entire `LibreRadioActivity/` widget extension target (Live Activity + Home Screen widget)
- Removed `Shared/` directory (RadioPlaybackAction, intents, NowPlayingWidgetData)
- Removed `LiveActivityService`, `WidgetDataService`, `RadioActivityAttributes`, App Group entitlements
- Removed all widget/Live Activity wiring from `AudioPlayerService` and `LibreRadioApp`
- Removed widget/Live Activity test files (WidgetDataServiceTests, NowPlayingWidgetDataTests)
- Lock screen playback controls continue to work via `NowPlayingService` (MPNowPlayingInfoCenter)
- Eliminates Apple Review Guideline 2.1 issue — no more `widgetkit-extension` bundle
- All 418 tests pass

## 2026-03-25 — Optimize caching for instantaneous app startup

**Prompt:** `/implement cache stations and favicons so the app start is instantaneous`

**Changes:**
- Added batch `loadHomeData(localCountryCode:)` method to `StationCacheService` with `HomeCacheData` struct — reads all 5 home cache keys in a single actor hop instead of 5 sequential hops
- Restructured `HomeViewModel.load()` to clear `isLoading` immediately after cached data is assigned, eliminating the loading spinner flash on warm-cache launches
- Added `preWarmMemoryCache(for:)` to `ImageCacheService` — promotes disk-cached favicons to NSCache for up to 60 URLs on startup, eliminating the placeholder-to-image flash
- HomeViewModel now launches favicon pre-warming as a non-blocking background Task after cache load
- Added 9 new tests: `loadHomeData` batch loading (4 tests), `preWarmMemoryCache` behavior (4 tests), cache-first loading state (1 test) — all 432 tests pass

## 2026-03-24 — Implement 5 code quality improvements from technical review

**Prompt:** `/implement P2-6 (StationConvertible), P2-8 (AsyncContentView), P3-2 (AlphabetIndexView accessibility), P3-7 (Test coverage), PlayerViewModel polling replacement`

**Changes:**
- Added `StationConvertible` protocol with default `toStationDTO()` — eliminates duplicate 25-field initializer boilerplate in `FavoriteStation` and `HistoryEntry`
- Added `AsyncContentView` generic wrapper — consolidates loading → error → empty → content state pattern across 3 views (`StationListView`, `FavoritesView`, `RecentStationsView`); HomeView kept inline as it has no true empty state
- Added VoiceOver accessibility to `AlphabetIndexView` — each letter has `accessibilityLabel`, `.isButton` trait, hint, and `onTapGesture` for activation; extracted `letterIndex(forY:letterCount:)` as static for testability
- Replaced PlayerViewModel 100ms polling `Task` with event-driven `AsyncStream<Void>` observation of `AudioPlayerService.stateChanges` — zero-latency, no wasted cycles
- Added `stateChanges` AsyncStream + `notifyStateChange()` to `AudioPlayerService` with calls at all state mutation points
- Added 3 new test files: `StationConvertibleTests` (5 tests), `StringTagListTests` (9 tests), `AlphabetIndexViewTests` (9 tests) — 23 new tests total, all 423 pass

## 2026-03-23 — Technical review: fix convention violations and code quality issues

**Prompt:** `/implement perform a general technical review of code and architecture and recommendations of things to improve`

**Changes:**
- Removed Combine dependency from `PlayerViewModel` — replaced `AnyCancellable` sink with a polling `Task` that monitors AudioPlayerService state changes every 100ms, eliminating the only Combine usage in the project
- Replaced `withCheckedThrowingContinuation` bridging in `RadioBrowserService.performRequest()` with native `URLSession.data(from:)` async API (available iOS 15+)
- Eliminated force unwraps: consolidated `ServerDiscoveryService` fallback URL into a single `static let`, replaced `ImageCacheService` init `first!` with `guard let` + `fatalError`, replaced `FullPlayerView` URL force unwrap with conditional `if let`
- Improved `NowPlayingService` remote command handlers to return `.noActionableNowPlayingItem` when weak references are nil instead of silently returning `.success`
- Extracted duplicate tag parsing logic from `StationDTO` and `FavoriteStation` into shared `String.asTagList` extension (`String+TagList.swift`)
- Improved `HomeViewModel` error mapping — now distinguishes `URLError` codes instead of mapping all unknown errors to `.networkUnavailable`
- Extracted magic numbers in `LiveActivityService` (`staleInterval`) and `ImageCacheService` (`memoryCacheLimit`) to named constants
- Added technical review implementation notes to `PLAN.md` documenting findings, fixes, and remaining recommendations

## 2026-03-22 — Revert alphabet index to simple direct-mapping scroll

**Prompt:** `/implement recently there was an improvement to the alphabet index for sorted lists in browse section. the alphabet functionality is too hard to use because scrolling through the list is very cumbersome. I like the idea of having alphabet + numbers + # symbol for everything else. Go back to the old way of scrolling though the index list`

**Changes:**
- Reverted `AlphabetIndexView` from the GeometryReader/clipping/auto-scroll implementation back to the simple VStack with direct linear gesture mapping
- Removed overflow handling (scroll offset, clipped container, fraction-based centering) — all letters are now rendered at full height with direct finger-to-letter mapping
- Kept the alphabet + numbers + `#` section categorization unchanged (that logic lives in the list views, not AlphabetIndexView)

## 2026-03-22 — Track history browsing in full player

**Prompt:** `/implement in expanded listening now, where the name of artist/song is displayed, show left arrow (and right arrow if left arrows was pressed) so the user can read previously listenes songs. If the user taps in the name of the current song, show a history list of every played song and a timestamp. When there is no artist and song available, write the station name`

**Changes:**
- Added `TrackHistoryItem` model for in-memory, session-scoped track metadata history
- Added `trackHistory` array to `AudioPlayerService`, populated from ICY metadata in `parseStreamTitle` with dedup against consecutive identical entries
- Added track browse index and navigation methods to `PlayerViewModel` (`browseTrackBack`, `browseTrackForward`, `browsedTrackTitle`, `browsedArtist`)
- Replaced the static track info section in `FullPlayerView` with left/right chevron browse controls
- Station name shown as fallback when no ICY metadata is available
- Created `TrackHistorySheet` view — tapping track info opens a sheet with full session history (reverse chronological, with relative timestamps)
- Track history is cross-station and survives stop/station changes (session-scoped, not persisted)
- Added 24 new tests across `TrackHistoryItemTests`, `AudioPlayerServiceTests`, and `PlayerViewModelTests`

## 2026-03-22 — Show country + subdivision in full player

**Prompt:** `/implement show {country flag} {country full name} {countrysubdivision}. For example 🇳🇱 Netherlands, Amsterdam. If there is no countrysubdivision, just show 🇳🇱 Netherlands`

**Changes:**
- Changed full player country/language section to show flag + full country name + subdivision (e.g. "🇦🇷 Argentina, Buenos Aires") instead of flag + country + language
- If no subdivision is available, shows just flag + country name (e.g. "🇳🇱 Netherlands")
- Language is no longer displayed in the full player location line
- Modified `FullPlayerView.swift` only — no model changes needed

## 2026-03-22 — Fix language sorting by name with diacritics and overflow

**Prompt:** `/implement fix sorting by name in the language section. there was a previous attempt to fix it already`

**Changes:**
- Fixed `LanguageListView.sectionedLanguages` to fold diacritics when computing section keys (č → C, ö → O, ś → S) using `String.folding(options:locale:)`, so accented Latin languages sort with their base letters instead of after Z
- Non-Latin scripts (Cyrillic, CJK, Arabic) are grouped under a single trailing "#" section instead of creating dozens of individual sections
- Updated `AlphabetIndexView` to handle overflow: uses `GeometryReader` to detect when letters exceed available height, clips the VStack, and scrolls the sidebar to keep the selected letter visible during drag
- Added `languageSectionKey(for:)` helper function (internal, testable) extracted from the sectioning logic
- Added 4 new tests for section key computation: plain Latin, diacritics folding, non-Latin grouping, edge cases

## 2026-03-22 — Persist lock screen info after stop

**Prompt:** `/implement when the user press stop in the locked screen keep the star button, the station image, and the station name and current tune`

**Changes:**
- Added `stopNowPlaying()` method to `NowPlayingService` that sets `playbackRate = 0` while preserving all metadata (station name, artwork, track info, like button state)
- Changed `AudioPlayerService.stop()` to call `stopNowPlaying()` instead of `clearNowPlaying()`, so lock screen/Control Center retains station info after stop
- Fixed `handleLikeCommand()` to fall back to `lastPlayedStation` when `currentStation` is nil, making the star button functional even after stop
- Added 3 new tests: `testStopNowPlayingPreservesInfo`, `testStopNowPlayingPreservesArtist`, `testStopNowPlayingPreservesStreamMetadata`
- Updated SPEC.md and PLAN.md to document the new stop behavior

## 2026-03-22 — Filter junk language entries in Browse

**Prompt:** `/implement fix the languages section in browse which looks bad when sorting by name`

**Changes:**
- Added filtering in `BrowseViewModel.sortedLanguages` to exclude language entries whose names start with non-letter characters (`#`, `+`, digits, symbols) or have zero stations
- Filter uses `Character.isLetter` which is Unicode-aware, preserving legitimate names in any script (Latin, Cyrillic, Arabic, CJK, etc.)
- Added 4 new tests covering junk filtering, non-Latin script preservation, zero station count exclusion, and whitespace trimming
- Updated SPEC.md to document the filtering behavior

## 2026-03-22 — Home redesign

**Prompt:** `/implement make the home section better regarding font sizes and empty spaces. Also make sections look better.`

**Changes:**
- Replaced `List(.insetGrouped)` with `ScrollView` + `LazyVStack` in HomeView for a fluid, edge-to-edge layout without grouped card backgrounds
- Increased section title font from `.headline` to `.title2.bold()` to have bold typography
- Enlarged station cards: width 130→160pt, favicon 64→80pt, name font `.caption`→`.subheadline`
- Tightened spacing between sections and cards for better content density
- Styled vertical sections (Recently Changed, Now Playing) with rounded containers and dividers
- Fixed pre-existing Simulator crash in `AudioPlayerService.setupRouteDetector()` by guarding `AVRouteDetector` KVO with `#if !targetEnvironment(simulator)`
