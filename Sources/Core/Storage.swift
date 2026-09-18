import Foundation

public enum SharedSettings {
    public static let group = "group.app.raceweek.personal"
    public static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
    public static var language: String { get { defaults.string(forKey: "language") ?? "system" } set { defaults.set(newValue, forKey: "language") } }
    public static var chinese: Bool { language == "zh" || (language == "system" && (Locale.preferredLanguages.first ?? "").hasPrefix("zh")) }
    public static var zoneMode: String { get { defaults.string(forKey: "zone") ?? "local" } set { defaults.set(newValue, forKey: "zone") } }
    public static func zone(for race: Race?) -> TimeZone { zoneMode == "track" ? race?.trackZone ?? .current : .current }
}

public enum Cache {
    public static func directory() -> URL {
        let fm = FileManager.default
        #if os(iOS)
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: SharedSettings.group) ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #else
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("RaceWeekTests")
        #endif
        return base.appendingPathComponent("RaceWeekCache", isDirectory: true)
    }
    public static func read<T: Codable>(_ type: T.Type, key: String) -> Snapshot<T>? {
        guard let data = try? Data(contentsOf: directory().appendingPathComponent(key + ".json")) else { return nil }
        return try? JSONDecoder().decode(Snapshot<T>.self, from: data)
    }
    public static func save<T: Codable>(_ snapshot: Snapshot<T>, key: String) throws {
        try FileManager.default.createDirectory(at: directory(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: directory().appendingPathComponent(key + ".json"), options: .atomic)
    }
    public static func key(_ year: Int, _ kind: String) -> String { "\(year)-\(kind)" }
    public static func fresh(_ date: Date, now: Date = Date(), seconds: TimeInterval = 900) -> Bool { now.timeIntervalSince(date) >= 0 && now.timeIntervalSince(date) < seconds }
}
