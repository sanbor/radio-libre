import XCTest
@testable import LibreRadio

/// Runtime tests for the AppKit bridge used by MenuBarService on Mac Catalyst.
///
/// These tests ONLY run on a Mac Catalyst destination. On iOS Simulator they are
/// skipped (the AppKit classes don't exist in-process).
///
/// Every method in AppKitBridge is string-typed (selector names, KVC keys). A typo
/// in a key like "system" instead of "systemStatusBar", or "isEnabled" instead of
/// "enabled", compiles clean and fails only at runtime. These tests catch those.
#if targetEnvironment(macCatalyst)
@MainActor
final class MenuBarBridgeTests: XCTestCase {

    func testSystemStatusBarReturnsObject() {
        XCTAssertNotNil(
            AppKitBridge.systemStatusBar(),
            "NSStatusBar.systemStatusBar must resolve at runtime — if this fails, the selector name is wrong"
        )
    }

    func testCreateStatusItem() {
        guard let bar = AppKitBridge.systemStatusBar() else {
            return XCTFail("prerequisite: systemStatusBar")
        }
        let item = AppKitBridge.createStatusItem(from: bar)
        XCTAssertNotNil(item, "statusItem(withLength:) must return a valid NSStatusItem")
    }

    func testCreateMenu() {
        let menu = AppKitBridge.createMenu(title: "Test")
        XCTAssertNotNil(menu, "NSMenu initWithTitle: must return a valid menu")
        XCTAssertEqual(menu?.value(forKey: "title") as? String, "Test")
    }

    func testCreateMenuItem() {
        let item = AppKitBridge.createMenuItem(title: "Item", action: nil)
        XCTAssertNotNil(item, "NSMenuItem initWithTitle:action:keyEquivalent: must return a valid item")
        XCTAssertEqual(item?.value(forKey: "title") as? String, "Item")
    }

    func testSeparatorItem() {
        XCTAssertNotNil(
            AppKitBridge.separatorItem(),
            "NSMenuItem.separatorItem class method must resolve at runtime"
        )
    }

    func testSystemImage() {
        XCTAssertNotNil(
            AppKitBridge.systemImage(name: "antenna.radiowaves.left.and.right"),
            "NSImage imageWithSystemSymbolName:accessibilityDescription: must return a valid NSImage"
        )
    }

    func testSetEnabledKVC() {
        guard let item = AppKitBridge.createMenuItem(title: "Item", action: nil) else {
            return XCTFail("prerequisite: createMenuItem")
        }
        // This exercises the KVC key for NSMenuItem's enabled property.
        // The key must be "enabled" (maps to setEnabled:), not "isEnabled"
        // (which would look for setIsEnabled: and fail with NSUnknownKeyException).
        AppKitBridge.setEnabled(false, on: item)
        XCTAssertEqual(item.value(forKey: "isEnabled") as? Bool, false)
        AppKitBridge.setEnabled(true, on: item)
        XCTAssertEqual(item.value(forKey: "isEnabled") as? Bool, true)
    }

    func testSetStateKVC() {
        guard let item = AppKitBridge.createMenuItem(title: "Item", action: nil) else {
            return XCTFail("prerequisite: createMenuItem")
        }
        AppKitBridge.setState(1, on: item)
        XCTAssertEqual(item.value(forKey: "state") as? Int, 1)
    }

    func testSetSubmenuKVC() {
        guard let parent = AppKitBridge.createMenuItem(title: "Parent", action: nil),
              let submenu = AppKitBridge.createMenu(title: "Sub") else {
            return XCTFail("prerequisite: create parent/submenu")
        }
        AppKitBridge.setSubmenu(submenu, on: parent)
        XCTAssertNotNil(parent.value(forKey: "submenu"))
    }

    func testAddAndRemoveItems() {
        guard let menu = AppKitBridge.createMenu(),
              let itemA = AppKitBridge.createMenuItem(title: "A", action: nil),
              let itemB = AppKitBridge.createMenuItem(title: "B", action: nil) else {
            return XCTFail("prerequisite: menu/items")
        }
        AppKitBridge.addItem(itemA, to: menu)
        AppKitBridge.addItem(itemB, to: menu)
        XCTAssertEqual((menu.value(forKey: "itemArray") as? [Any])?.count, 2)

        AppKitBridge.removeAllItems(from: menu)
        XCTAssertEqual((menu.value(forKey: "itemArray") as? [Any])?.count, 0)
    }

    /// Integration smoke test: MenuBarService.setup() does not crash and produces
    /// a non-empty menu. If the runtime bridge is broken, this test catches it.
    func testMenuBarServiceSetupProducesNonEmptyMenu() async {
        let playerVM = PlayerViewModel.shared
        let favoritesVM = FavoritesViewModel()
        await favoritesVM.load()

        // setup() is idempotent; the singleton may already be set up from a prior test.
        MenuBarService.shared.setup(playerVM: playerVM, favoritesVM: favoritesVM)

        // After setup, trigger a menu rebuild manually by invoking menuNeedsUpdate:
        // on the attached menu to ensure the build path works end-to-end.
        let menu = MenuBarService.shared.attachedMenuForTesting
        XCTAssertNotNil(menu, "MenuBarService should have attached a menu to the status item")

        if let menu {
            MenuBarService.shared.menuNeedsUpdate(menu)
            let items = menu.value(forKey: "itemArray") as? [Any]
            XCTAssertNotNil(items)
            XCTAssertGreaterThan(items?.count ?? 0, 0, "Menu must have at least one item after rebuild")
        }
    }
}
#endif
