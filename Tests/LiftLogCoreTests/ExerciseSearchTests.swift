import XCTest
@testable import LiftLogCore

final class ExerciseSearchTests: XCTestCase {
    private func exercise(_ name: String, id: String? = nil) -> CatalogExercise {
        CatalogExercise(exerciseId: id ?? name, name: name, gifUrl: "https://static.exercisedb.dev/media/test.gif", bodyParts: ["back"], equipments: ["dumbbell"], targetMuscles: ["lats"], secondaryMuscles: [], instructions: [])
    }
    func testDumbbellRowExcludesCurlsAndPressesButIncludesNamedVariations() {
        let names = ["dumbbell standing reverse curl", "dumbbell incline row", "dumbbell bent over row", "Dumbbell Single-Arm Bent-Over Row", "dumbbell bench press", "barbell bent over row"]
        let result = ExerciseSearch.sorted(names.map { exercise($0) }, query: "dumbbell row")
        XCTAssertEqual(Set(result.map(\.name)), Set(["dumbbell incline row", "dumbbell bent over row", "Dumbbell Single-Arm Bent-Over Row"]))
    }
    func testExactNameRanksFirstAndQueryWordOrderIsFlexible() {
        let rows = [exercise("dumbbell row on bench"), exercise("dumbbell bent over row"), exercise("Dumbbell Row")]
        XCTAssertEqual(ExerciseSearch.sorted(rows, query: "dumbbell row").first?.name, "Dumbbell Row")
        XCTAssertEqual(ExerciseSearch.sorted(rows, query: "row dumbbell").count, 3)
    }
    func testCasePunctuationPluralsAndAbbreviations() {
        XCTAssertTrue(ExerciseSearch.matches("Dumbbell Single-Arm Bent-Over Row", query: " DB single arm rows "))
        XCTAssertTrue(ExerciseSearch.matches("Barbell Bench Press", query: "bb bench presses"))
        XCTAssertFalse(ExerciseSearch.matches("dumbbell around pullover", query: "dumbbell row"))
        XCTAssertFalse(ExerciseSearch.matches("barbell row", query: "dumbbell row"))
    }
    func testProviderQueryUsesLiveTaxonomyAndKeepsExplicitFiltersAndCursor() {
        let query = CatalogQuery(name: "Dumbbell row", muscle: "lats", bodyPart: "back", cursor: "next")
        let planned = ExerciseSearch.providerQuery(query, equipments: ["dumbbell", "barbell"])
        XCTAssertEqual(planned.name, "row"); XCTAssertEqual(planned.equipment, "dumbbell")
        XCTAssertEqual(planned.muscle, "lats"); XCTAssertEqual(planned.bodyPart, "back"); XCTAssertEqual(planned.cursor, "next")
        var explicit = query; explicit.equipment = "barbell"
        XCTAssertEqual(ExerciseSearch.providerQuery(explicit, equipments: ["dumbbell"]).equipment, "barbell")
        XCTAssertEqual(ExerciseSearch.providerQuery(CatalogQuery(name: "DB rows"), equipments: ["dumbbell"]).url,
                       ExerciseSearch.providerQuery(CatalogQuery(name: "dumbbells row"), equipments: ["dumbbell"]).url)
    }
    func testSearchMovesPastIrrelevantPagesAndCachesProviderRequests() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = CatalogPage(success: true, meta: .init(total: 2, hasNextPage: true, nextCursor: "next"), data: [exercise("dumbbell curl")])
        let second = CatalogPage(success: true, meta: .init(total: 2, hasNextPage: false, nextCursor: nil), data: [exercise("dumbbell bent over row")])
        let stub = SearchTransport(pages: [try JSONEncoder().encode(first), try JSONEncoder().encode(second)])
        let catalog = ExerciseCatalog(directory: folder, spacing: 0, transport: { try await stub.fetch($0) })
        let page = try await catalog.searchPage(CatalogQuery(name: "dumbbell row"))
        XCTAssertEqual(page.data.map(\.name), ["dumbbell bent over row"]); XCTAssertNil(page.nextCursor)
        _ = try await catalog.searchPage(CatalogQuery(name: "DB rows"))
        let calls = await stub.count(); XCTAssertEqual(calls, 3) // taxonomy + two pages, then all cache hits
    }
    func testSearchStopsAtThreePagesAndExposesRemainingCursor() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pages = try (0..<4).map { index in
            try JSONEncoder().encode(CatalogPage(success: true, meta: .init(total: 100, hasNextPage: true, nextCursor: String(index + 1)), data: [exercise("dumbbell curl", id: String(index))]))
        }
        let stub = SearchTransport(pages: pages)
        let catalog = ExerciseCatalog(directory: folder, spacing: 0, transport: { try await stub.fetch($0) })
        let page = try await catalog.searchPage(CatalogQuery(name: "dumbbell row"))
        XCTAssertTrue(page.data.isEmpty); XCTAssertEqual(page.nextCursor, "3")
        let calls = await stub.count(); XCTAssertEqual(calls, 4)
    }
}
private actor SearchTransport {
    let pages: [Data]
    var calls = 0
    var pageIndex = 0
    init(pages: [Data]) { self.pages = pages }
    func count() -> Int { calls }
    func fetch(_ url: URL) throws -> (Data, HTTPURLResponse) {
        calls += 1
        let data: Data
        if url.path.hasSuffix("equipments") {
            data = try JSONEncoder().encode(CatalogEnvelope(success: true, data: [CatalogFacet(name: "dumbbell")]))
        } else {
            data = pages[min(pageIndex, pages.count - 1)]; pageIndex += 1
        }
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
