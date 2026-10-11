import XCTest
@testable import LiftLogCore

private final class CatalogClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_800_000_000)
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ interval: TimeInterval) { lock.lock(); defer { lock.unlock() }; value.addTimeInterval(interval) }
}
private actor CatalogStub {
    var calls: [URL] = []
    var status = 200
    var headers: [String: String] = [:]
    var offline = false
    var bytes: Data
    init(_ bytes: Data) { self.bytes = bytes }
    func configure(status: Int = 200, headers: [String: String] = [:], offline: Bool = false, bytes: Data? = nil) {
        self.status = status; self.headers = headers; self.offline = offline
        if let bytes { self.bytes = bytes }
    }
    func count() -> Int { calls.count }
    func fetch(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        calls.append(url)
        try await Task.sleep(for: .milliseconds(20))
        if offline { throw URLError(.notConnectedToInternet) }
        return (bytes, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}
final class ExerciseCatalogTests: XCTestCase {
    private var directory: URL!
    private let sample = CatalogExercise(exerciseId: "abc123", name: "dumbbell curl", gifUrl: "https://static.exercisedb.dev/media/abc123.gif", bodyParts: ["upper arms"], equipments: ["dumbbell"], targetMuscles: ["biceps"], secondaryMuscles: ["forearms"], instructions: ["Step:1 Curl the dumbbells."])
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }
    private func page() throws -> Data {
        try JSONEncoder().encode(CatalogPage(success: true, meta: .init(total: 40, hasNextPage: true, nextCursor: "abc123"), data: [sample]))
    }
    private func client(_ stub: CatalogStub, clock: CatalogClock = CatalogClock()) -> ExerciseCatalog {
        ExerciseCatalog(directory: directory, spacing: 0, now: { clock.now() }, transport: { try await stub.fetch($0) })
    }
    func testQueryEncodingAndPaginationKeepAllFilters() {
        let url = CatalogQuery(name: " Curl & press ", muscle: "biceps", bodyPart: "upper arms", equipment: "EZ bar", cursor: "a+b").url
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        XCTAssertEqual(values, ["name":"curl & press", "targetMuscles":"biceps", "bodyParts":"upper arms", "equipments":"EZ bar", "after":"a+b", "limit":"25"])
        XCTAssertEqual(CatalogQuery(name: " CURL ").url, CatalogQuery(name: "curl").url)
    }
    func testConcurrentRequestsCoalesceAndCacheSurvivesRelaunch() async throws {
        let stub = CatalogStub(try page()); let catalog = client(stub)
        async let first = catalog.page(CatalogQuery())
        async let second = catalog.page(CatalogQuery())
        let pages = try await [first, second]
        XCTAssertEqual(pages[0].data, [sample]); XCTAssertEqual(pages[1].meta.nextCursor, "abc123")
        let count = await stub.count(); XCTAssertEqual(count, 1)
        await stub.configure(offline: true)
        let reopened = client(stub)
        let cached = try await reopened.page(CatalogQuery())
        XCTAssertEqual(cached.data, [sample])
        let after = await stub.count(); XCTAssertEqual(after, 1)
    }
    func testExpiryRefetchesAndExpiredCacheIsNotAnOfflineFallback() async throws {
        let clock = CatalogClock(); let stub = CatalogStub(try page()); let catalog = client(stub, clock: clock)
        _ = try await catalog.page(CatalogQuery())
        clock.advance(3599); _ = try await catalog.page(CatalogQuery())
        let before = await stub.count(); XCTAssertEqual(before, 1)
        clock.advance(1); _ = try await catalog.page(CatalogQuery())
        let after = await stub.count(); XCTAssertEqual(after, 2)
        clock.advance(3601); await stub.configure(offline: true)
        do { _ = try await catalog.page(CatalogQuery()); XCTFail("Expired response must not be used") } catch {}
    }
    func testRetryAfterPersistsAndDoesNotBlockFreshCache() async throws {
        let clock = CatalogClock(); let stub = CatalogStub(try page()); let catalog = client(stub, clock: clock)
        _ = try await catalog.page(CatalogQuery())
        await stub.configure(status: 429, headers: ["Retry-After":"120"])
        do { _ = try await catalog.page(CatalogQuery(name: "new")); XCTFail() } catch CatalogError.throttled(let until) { XCTAssertEqual(until, clock.now().addingTimeInterval(120)) }
        let reopened = client(stub, clock: clock)
        _ = try await reopened.page(CatalogQuery())
        await reopened.clearCache()
        do { _ = try await reopened.page(CatalogQuery(name: "another")); XCTFail() } catch CatalogError.throttled {}
        let count = await stub.count(); XCTAssertEqual(count, 2)
        clock.advance(121); await stub.configure()
        _ = try await reopened.page(CatalogQuery(name: "another"))
        let resumed = await stub.count(); XCTAssertEqual(resumed, 3)
    }
    func testInvalidPayloadNotCachedAndCorruptDiskRecovers() async throws {
        let stub = CatalogStub(Data("{\"success\":false}".utf8)); let catalog = client(stub)
        do { _ = try await catalog.page(CatalogQuery()); XCTFail() } catch CatalogError.invalidResponse {}
        await stub.configure(bytes: try page())
        _ = try await catalog.page(CatalogQuery())
        let file = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.pathExtension == "json" }!
        try Data("corrupt".utf8).write(to: file)
        _ = try await catalog.page(CatalogQuery())
        let count = await stub.count(); XCTAssertEqual(count, 3)
    }
    func testNoStoreAndShorterServerTTL() async throws {
        let clock = CatalogClock(); let stub = CatalogStub(try page()); let catalog = client(stub, clock: clock)
        await stub.configure(headers: ["Cache-Control":"no-store"])
        _ = try await catalog.page(CatalogQuery()); _ = try await catalog.page(CatalogQuery())
        let count = await stub.count(); XCTAssertEqual(count, 2)
        await stub.configure(headers: ["Cache-Control":"max-age=10", "Age":"5"])
        _ = try await catalog.page(CatalogQuery()); clock.advance(5)
        _ = try await catalog.page(CatalogQuery())
        let refreshed = await stub.count(); XCTAssertEqual(refreshed, 4)
    }
    func testDetailsFacetsAndMediaUseSameCacheAndRejectUntrustedHost() async throws {
        let stub = CatalogStub(try JSONEncoder().encode(CatalogEnvelope(success: true, data: sample)))
        let catalog = client(stub)
        let detail = try await catalog.detail("abc123"); XCTAssertEqual(detail, sample)
        await stub.configure(bytes: try JSONEncoder().encode(CatalogEnvelope(success: true, data: [CatalogFacet(name: "biceps"), CatalogFacet(name: "biceps")])))
        let facets = try await catalog.facets("muscles"); XCTAssertEqual(facets, ["biceps"])
        await stub.configure(bytes: Data("GIF89a".utf8))
        _ = try await catalog.animation(sample.gifUrl); _ = try await catalog.animation(sample.gifUrl)
        do { _ = try await catalog.animation("https://example.com/image.gif"); XCTFail() } catch CatalogError.invalidResponse {}
        do { _ = try await catalog.detail("../exercises"); XCTFail() } catch CatalogError.invalidResponse {}
        let count = await stub.count(); XCTAssertEqual(count, 3)
    }
    func testHTTPDateRetryAfterAndFallbackCooldown() async throws {
        let clock = CatalogClock(); let stub = CatalogStub(try page()); let catalog = client(stub, clock: clock)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        await stub.configure(status: 429, headers: ["Retry-After": formatter.string(from: clock.now().addingTimeInterval(90))])
        do { _ = try await catalog.page(CatalogQuery()); XCTFail() }
        catch CatalogError.throttled(let until) { XCTAssertEqual(until, clock.now().addingTimeInterval(90)) }
        clock.advance(91); await stub.configure(status: 429)
        do { _ = try await catalog.page(CatalogQuery()); XCTFail() }
        catch CatalogError.throttled(let until) { XCTAssertEqual(until, clock.now().addingTimeInterval(60)) }
    }
    func testCacheClearInvalidatesDownloadsButNotUserRecords() async throws {
        let stub = CatalogStub(try page()); let catalog = client(stub)
        let downloaded = try await catalog.page(CatalogQuery())
        let record = downloaded.data[0].record
        await catalog.clearCache(); await stub.configure(offline: true)
        do { _ = try await catalog.page(CatalogQuery()); XCTFail() } catch CatalogError.unavailable {}
        let userData = Backup(exercises: [record], days: [], sessions: [], preferences: Preferences())
        XCTAssertEqual(try Backup.decode(userData.encoded()).exercises[0], record)
    }
    func testCachedPagesAreDistinctAcrossCursorAndFilters() async throws {
        let stub = CatalogStub(try page()); let catalog = client(stub)
        _ = try await catalog.page(CatalogQuery(name: "curl", muscle: "biceps"))
        _ = try await catalog.page(CatalogQuery(name: "curl", muscle: "biceps", cursor: "abc123"))
        _ = try await catalog.page(CatalogQuery(name: "curl", muscle: "biceps", equipment: "dumbbell"))
        _ = try await catalog.page(CatalogQuery(name: "curl", muscle: "biceps"))
        let count = await stub.count(); XCTAssertEqual(count, 3)
    }
    func testProviderIdentityAndOldBackupsPreserved() throws {
        var renamed = sample.record; renamed.name = "My curl"
        XCTAssertEqual(renamed.id, sample.record.id)
        XCTAssertNotEqual(sample.record.id, ExerciseLibrary.catalog[0].id)
        let day = DayRecord(type: .pull, exerciseIDs: [renamed.id])
        let backup = Backup(exercises: [renamed], days: [day], sessions: [], preferences: Preferences())
        let decoded = try Backup.decode(backup.encoded())
        XCTAssertEqual(decoded.exercises, [renamed]); XCTAssertEqual(decoded.exercises[0].exerciseDBID, "abc123")
        let old = Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"Curl\",\"muscle\":\"Biceps\",\"isBodyweight\":false}".utf8)
        let legacy = try JSONDecoder().decode(ExerciseRecord.self, from: old)
        XCTAssertNil(legacy.exerciseDBID); XCTAssertEqual(legacy.name, "Curl")
    }
}
