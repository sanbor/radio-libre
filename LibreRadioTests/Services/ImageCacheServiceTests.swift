import XCTest
@testable import LibreRadio

final class ImageCacheServiceTests: XCTestCase {
    private var sut: ImageCacheService!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let session = TestFixtures.makeMockSession()
        sut = ImageCacheService(session: session, cacheDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        MockURLProtocol.requestHandler = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTestPNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.pngData { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private func setMockImageResponse(url: URL, data: Data, statusCode: Int = 200) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: statusCode,
                httpVersion: nil, headerFields: nil
            )!
            return (response, data)
        }
    }

    // MARK: - Tests

    func testNetworkLoadReturnsImage() async {
        let url = URL(string: "https://example.com/icon.png")!
        let pngData = makeTestPNGData()
        setMockImageResponse(url: url, data: pngData)

        let image = await sut.image(for: url)
        XCTAssertNotNil(image)
    }

    func testMemoryCacheHit() async {
        let url = URL(string: "https://example.com/icon.png")!
        let pngData = makeTestPNGData()
        setMockImageResponse(url: url, data: pngData)

        // First load populates cache
        _ = await sut.image(for: url)

        // Track whether network was hit again
        var networkHit = false
        MockURLProtocol.requestHandler = { request in
            networkHit = true
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200,
                httpVersion: nil, headerFields: nil
            )!
            return (response, pngData)
        }

        // Second load should be from memory
        let image = await sut.image(for: url)
        XCTAssertNotNil(image)
        XCTAssertFalse(networkHit)
    }

    func testDiskCacheHit() async {
        let url = URL(string: "https://example.com/disk-icon.png")!
        let pngData = makeTestPNGData()
        setMockImageResponse(url: url, data: pngData)

        // First load populates both caches
        _ = await sut.image(for: url)

        // Create new instance with same disk dir (fresh memory cache)
        let session2 = TestFixtures.makeMockSession()
        var networkHit = false
        MockURLProtocol.requestHandler = { request in
            networkHit = true
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200,
                httpVersion: nil, headerFields: nil
            )!
            return (response, pngData)
        }

        let sut2 = ImageCacheService(session: session2, cacheDirectory: tempDir)
        let image = await sut2.image(for: url)
        XCTAssertNotNil(image)
        XCTAssertFalse(networkHit)
    }

    func testNilOnNetworkError() async {
        let url = URL(string: "https://example.com/fail.png")!
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let image = await sut.image(for: url)
        XCTAssertNil(image)
    }

    func testNilOnInvalidData() async {
        let url = URL(string: "https://example.com/bad.png")!
        setMockImageResponse(url: url, data: Data("not an image".utf8))

        let image = await sut.image(for: url)
        XCTAssertNil(image)
    }

    func testDifferentURLsDifferentFiles() async {
        let url1 = URL(string: "https://example.com/a.png")!
        let url2 = URL(string: "https://example.com/b.png")!
        let pngData = makeTestPNGData()
        setMockImageResponse(url: url1, data: pngData)

        _ = await sut.image(for: url1)
        _ = await sut.image(for: url2)

        let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files?.count, 2)
    }

    func testSHA256Consistency() async {
        let url = URL(string: "https://example.com/consistent.png")!
        let pngData = makeTestPNGData()
        setMockImageResponse(url: url, data: pngData)

        _ = await sut.image(for: url)
        _ = await sut.image(for: url)

        // Should still be just one file since same URL
        let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files?.count, 1)
    }

    func testSynchronousCachedImageAfterAsyncLoad() async {
        let url = URL(string: "https://example.com/sync.png")!
        let pngData = makeTestPNGData()
        setMockImageResponse(url: url, data: pngData)

        // Before load - should be nil
        let before = sut.cachedImage(for: url)
        XCTAssertNil(before)

        // After load - should work synchronously
        _ = await sut.image(for: url)
        let after = sut.cachedImage(for: url)
        XCTAssertNotNil(after)
    }

    func testNilOnNon200StatusCode() async {
        let url = URL(string: "https://example.com/404.png")!
        let pngData = makeTestPNGData()
        setMockImageResponse(url: url, data: pngData, statusCode: 404)

        let image = await sut.image(for: url)
        XCTAssertNil(image)
    }
}
