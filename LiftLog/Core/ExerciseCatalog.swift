import Foundation
import CryptoKit

struct CatalogExercise: Codable, Identifiable, Equatable, Sendable {
    let exerciseId: String
    let name: String
    let gifUrl: String
    let bodyParts: [String]
    let equipments: [String]
    let targetMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    var id: String { exerciseId }
    var record: ExerciseRecord {
        // Provider identities remain stable across searches, devices and backup restores.
        let bytes = Array(SHA256.hash(data: Data("ExerciseDB/v1/\(exerciseId)".utf8)).prefix(16))
        let uuid = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5],
                              (bytes[6] & 0x0f) | 0x50, bytes[7], (bytes[8] & 0x3f) | 0x80,
                              bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
        let equipment = Equipment.allCases.first { equipments.contains($0.rawValue.lowercased()) } ?? .other
        return ExerciseRecord(id: uuid, name: name, muscle: targetMuscles.joined(separator: ", "),
                              isBodyweight: equipments == ["bodyweight"], equipment: equipment,
                              exerciseDBID: exerciseId, equipmentDescription: equipments.joined(separator: ", "))
    }
}

struct CatalogPage: Codable, Sendable {
    struct Metadata: Codable, Sendable {
        let total: Int
        let hasNextPage: Bool
        let nextCursor: String?
    }
    let success: Bool
    let meta: Metadata
    let data: [CatalogExercise]
}

struct CatalogEnvelope<Value: Codable & Sendable>: Codable, Sendable {
    let success: Bool
    let data: Value
}
struct CatalogFacet: Codable, Sendable { let name: String }
struct CatalogQuery: Hashable, Sendable {
    var name = ""
    var muscle = ""
    var bodyPart = ""
    var equipment = ""
    var cursor: String? = nil
    var url: URL {
        var parts = URLComponents(string: ExerciseCatalog.api + "/exercises")!
        let values: [(String, String)] = [("name", name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
                                        ("targetMuscles", muscle), ("bodyParts", bodyPart), ("equipments", equipment),
                                        ("after", cursor ?? ""), ("limit", "25")]
        parts.queryItems = values.filter { !$0.1.isEmpty }.map { URLQueryItem(name: $0.0, value: $0.1) }
        return parts.url!
    }
}

enum CatalogError: LocalizedError {
    case unavailable, invalidResponse, missing, throttled(Date)
    var errorDescription: String? {
        switch self {
        case .unavailable: "Couldn’t reach ExerciseDB. Check your connection or use Saved exercises."
        case .invalidResponse: "ExerciseDB returned an unreadable response. Please try again later."
        case .missing: "This exercise is no longer available from ExerciseDB. Your saved workout is unchanged."
        case .throttled(let date): "ExerciseDB’s request limit was reached. Try again after \(date.formatted(date: .omitted, time: .standard)). Saved exercises still work."
        }
    }
}

/// A shared, bounded, on-disk cache. Only successful validated responses are cached.
/// Workout snapshots are user data and intentionally live outside this disposable cache.
actor ExerciseCatalog {
    static let api = "https://oss.exercisedb.dev/api/v1"
    static let ttl: TimeInterval = 3600
    static let shared = ExerciseCatalog()
    typealias Transport = @Sendable (URL) async throws -> (Data, HTTPURLResponse)
    private struct Entry: Codable { let url: String; let expires: Date; let data: Data }
    private let directory: URL
    private let transport: Transport
    private let now: @Sendable () -> Date
    private let spacing: TimeInterval
    private var nextRequest = Date.distantPast
    private var cooldown: Date = .distantPast
    private var pending: [URL: Task<Data, Error>] = [:]
    private var generation = 0

    init(directory: URL? = nil, spacing: TimeInterval = 0.6,
         now: @escaping @Sendable () -> Date = { Date() }, transport: Transport? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExerciseDB-v1", isDirectory: true)
        self.now = now
        self.spacing = spacing
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        self.transport = transport ?? { url in
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw CatalogError.invalidResponse }
            return (data, http)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        if let bytes = try? Data(contentsOf: self.directory.appendingPathComponent("cooldown")),
           let seconds = Double(String(decoding: bytes, as: UTF8.self)) {
            cooldown = Date(timeIntervalSince1970: seconds)
        }
    }

    func page(_ query: CatalogQuery) async throws -> CatalogPage {
        try await decoded(CatalogPage.self, url: query.url) { $0.success && $0.data.allSatisfy(Self.valid) }
    }
    func searchPage(_ query: CatalogQuery) async throws -> CatalogSearchPage {
        let equipmentNames = try await facets("equipments")
        try Task.checkCancellation()
        var request = ExerciseSearch.providerQuery(query, equipments: equipmentNames)
        var matches: [CatalogExercise] = []
        var seenIDs: Set<String> = []
        var seenCursors: Set<String> = []
        if let cursor = request.cursor { seenCursors.insert(cursor) }
        var nextCursor: String?
        // Bound work per user action. Reuse the same one-hour cache and global pacing.
        // Continue beyond irrelevant provider pages, but never fetch the whole catalog.
        for _ in 0..<3 {
            try Task.checkCancellation()
            let response = try await page(request)
            matches += response.data.filter { ExerciseSearch.matches($0.name, query: query.name) && seenIDs.insert($0.id).inserted }
            nextCursor = response.meta.hasNextPage ? response.meta.nextCursor : nil
            if let next = nextCursor, !seenCursors.insert(next).inserted { nextCursor = nil }
            guard let next = nextCursor, matches.count < 25 else { break }
            request.cursor = next
        }
        return CatalogSearchPage(data: ExerciseSearch.sorted(matches, query: query.name), nextCursor: nextCursor)
    }
    func detail(_ id: String) async throws -> CatalogExercise {
        guard !id.isEmpty, id.count <= 100, id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { throw CatalogError.invalidResponse }
        let response = try await decoded(CatalogEnvelope<CatalogExercise>.self, url: URL(string: Self.api + "/exercises/" + id)!) {
            $0.success && $0.data.exerciseId == id && Self.valid($0.data)
        }
        return response.data
    }
    func facets(_ path: String) async throws -> [String] {
        guard ["muscles", "bodyparts", "equipments"].contains(path) else { throw CatalogError.invalidResponse }
        let response = try await decoded(CatalogEnvelope<[CatalogFacet]>.self, url: URL(string: Self.api + "/" + path)!) {
            $0.success && $0.data.allSatisfy { !$0.name.isEmpty && $0.name.count <= 200 }
        }
        return Array(Set(response.data.map(\.name))).sorted()
    }
    func animation(_ address: String) async throws -> Data {
        guard let url = URL(string: address), url.scheme == "https", url.host == "static.exercisedb.dev",
              url.user == nil, url.password == nil, url.port == nil else { throw CatalogError.invalidResponse }
        return try await fetch(url, maximum: 8_000_000) { data in
            data.starts(with: Data("GIF87a".utf8)) || data.starts(with: Data("GIF89a".utf8))
        }
    }
    func clearCache() {
        generation += 1
        // Do not erase the rate-limit cooldown or cancel shared in-flight requests.
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "json" {
            try? FileManager.default.removeItem(at: url)
        }
    }
    private static func valid(_ exercise: CatalogExercise) -> Bool {
        !exercise.exerciseId.isEmpty && exercise.exerciseId.count <= 100 && !exercise.name.isEmpty && exercise.name.count <= 200
        && exercise.targetMuscles.joined(separator: ", ").count <= 200
    }
    private func decoded<T: Codable & Sendable>(_ type: T.Type, url: URL,
                                                validate: @escaping @Sendable (T) -> Bool) async throws -> T {
        let data = try await fetch(url, maximum: 2_000_000) {
            guard let value = try? JSONDecoder().decode(type, from: $0) else { return false }
            return validate(value)
        }
        return try JSONDecoder().decode(type, from: data)
    }
    private func file(_ url: URL) -> URL {
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(key + ".json")
    }
    private func fetch(_ url: URL, maximum: Int, validate: @escaping @Sendable (Data) -> Bool) async throws -> Data {
        let path = file(url)
        if let bytes = try? Data(contentsOf: path), let entry = try? JSONDecoder().decode(Entry.self, from: bytes),
           entry.url == url.absoluteString, entry.expires > now(), entry.data.count <= maximum, validate(entry.data) {
            return entry.data
        }
        try? FileManager.default.removeItem(at: path)
        if let task = pending[url] { return try await task.value }
        guard cooldown <= now() else { throw CatalogError.throttled(cooldown) }
        let currentGeneration = generation
        let task = Task { try await self.download(url, maximum: maximum, generation: currentGeneration, validate: validate) }
        pending[url] = task
        defer { pending[url] = nil }
        return try await task.value
    }
    private func download(_ url: URL, maximum: Int, generation: Int, validate: @Sendable (Data) -> Bool) async throws -> Data {
        let wait = max(0, nextRequest.timeIntervalSince(now()))
        nextRequest = now().addingTimeInterval(wait + spacing)
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
        guard cooldown <= now() else { throw CatalogError.throttled(cooldown) }
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await transport(url) }
        catch { throw CatalogError.unavailable }
        if response.statusCode == 429 {
            let header = response.value(forHTTPHeaderField: "Retry-After") ?? ""
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            let date = Double(header).map { now().addingTimeInterval(max(1, $0)) } ?? formatter.date(from: header) ?? now().addingTimeInterval(60)
            cooldown = max(cooldown, max(date, now().addingTimeInterval(1)))
            try? Data(String(cooldown.timeIntervalSince1970).utf8).write(to: directory.appendingPathComponent("cooldown"), options: .atomic)
            throw CatalogError.throttled(cooldown)
        }
        if response.statusCode == 404 { throw CatalogError.missing }
        guard response.statusCode == 200 else { throw CatalogError.unavailable }
        guard data.count <= maximum, validate(data) else { throw CatalogError.invalidResponse }
        let directives = (response.value(forHTTPHeaderField: "Cache-Control") ?? "").lowercased().components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var lifetime = Self.ttl
        if let maxAge = directives.first(where: { $0.hasPrefix("max-age=") }), let seconds = Double(maxAge.dropFirst(8)) {
            lifetime = min(lifetime, max(0, seconds - (Double(response.value(forHTTPHeaderField: "Age") ?? "") ?? 0)))
        }
        if generation == self.generation, lifetime > 0, !directives.contains("no-store"), !directives.contains("no-cache") {
            let entry = Entry(url: url.absoluteString, expires: now().addingTimeInterval(lifetime), data: data)
            if let bytes = try? JSONEncoder().encode(entry) { try? bytes.write(to: file(url), options: .atomic) }
            prune()
        }
        return data
    }
    private func prune() {
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []).filter { $0.pathExtension == "json" }
        var retained: [(URL, Date, Int)] = []
        for url in files {
            guard let bytes = try? Data(contentsOf: url), let entry = try? JSONDecoder().decode(Entry.self, from: bytes), entry.expires > now() else {
                try? FileManager.default.removeItem(at: url); continue
            }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            retained.append((url, date, bytes.count))
        }
        retained.sort { $0.1 > $1.1 }
        var size = 0
        for (index, item) in retained.enumerated() {
            size += item.2
            if index >= 250 || size > 32_000_000 { try? FileManager.default.removeItem(at: item.0) }
        }
    }
}
