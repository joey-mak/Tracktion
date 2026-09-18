import Foundation

public enum SessionKind: String, Codable, CaseIterable, Sendable {
    case fp1, fp2, fp3, sprintQualifying, sprint, qualifying, race
    public func title(_ zh: Bool) -> String {
        switch self {
        case .fp1: return zh ? "练习赛 1" : "Practice 1"
        case .fp2: return zh ? "练习赛 2" : "Practice 2"
        case .fp3: return zh ? "练习赛 3" : "Practice 3"
        case .sprintQualifying: return zh ? "冲刺排位赛" : "Sprint qualifying"
        case .sprint: return zh ? "冲刺赛" : "Sprint"
        case .qualifying: return zh ? "排位赛" : "Qualifying"
        case .race: return zh ? "正赛" : "Race"
        }
    }
    public var code: String {
        switch self { case .fp1: "FP1"; case .fp2: "FP2"; case .fp3: "FP3"; case .sprintQualifying: "SQ"; case .sprint: "SPR"; case .qualifying: "Q"; case .race: "GP" }
    }
}

public struct Session: Codable, Identifiable, Sendable {
    public let kind: SessionKind
    public let date: String
    public let time: String?
    public var id: String { kind.rawValue }
    public var start: Date? { RaceDate.parse(date, time: time) }
    public var day: Date? { RaceDate.day(date) }
    public init(kind: SessionKind, date: String, time: String?) { self.kind = kind; self.date = date; self.time = time }
}

public enum RaceDate {
    /// Unknown time is deliberately NOT treated as midnight or a scheduled start.
    public static func parse(_ date: String, time: String?) -> Date? {
        guard let time, !time.isEmpty else { return nil }
        let input = date + "T" + time
        let formatter = ISO8601DateFormatter()
        if let parsed = formatter.date(from: input) { return parsed }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: input)
    }
    public static func day(_ date: String) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date)
    }
    public static func dayString(_ date: Date, zone: TimeZone = .current) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

public struct Race: Codable, Identifiable, Sendable {
    public let season: Int
    public let round: Int
    public let name: String
    public let circuitID: String
    public let circuit: String
    public let city: String
    public let country: String
    public let date: String
    public let sessions: [Session]
    public var id: String { "\(season)-\(round)" }
    public var isSprint: Bool { sessions.contains { $0.kind == .sprint } }
    public func nextSession(after now: Date) -> Session? { sessions.filter { ($0.start ?? .distantPast) > now }.min { $0.start! < $1.start! } }
    public func title(_ zh: Bool) -> String { zh ? Names.races[name] ?? name : name }
    public func location(_ zh: Bool) -> String { zh ? "\(Names.cities[city] ?? city) · \(Names.countries[country] ?? country)" : "\(city) · \(country)" }
    public func circuitTitle(_ zh: Bool) -> String { zh ? Names.circuits[circuitID] ?? circuit : circuit }
    public var trackZone: TimeZone? { Names.zones[circuitID].flatMap(TimeZone.init(identifier:)) }
}

public enum ScheduleLogic {
    public static func nextRace(_ races: [Race], now: Date = Date()) -> Race? {
        let today = RaceDate.dayString(now)
        return races.sorted { $0.date < $1.date }.first { $0.date >= today || $0.nextSession(after: now) != nil }
    }
    public static func isThisWeek(_ race: Race, now: Date = Date()) -> Bool {
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = .current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
        return race.sessions.contains { s in
            if let start = s.start { return week.contains(start) }
            // Date-only fields remain in the source calendar; don't invent a local start.
            let monday = RaceDate.dayString(week.start)
            let sunday = RaceDate.dayString(week.end.addingTimeInterval(-1))
            return s.date >= monday && s.date <= sunday
        }
    }
}

public struct Standing: Codable, Identifiable, Sendable {
    public let id: String
    public let position: String
    public let name: String
    public let code: String
    public let teamID: String
    public let team: String
    public let points: String
    public let wins: String
    public func title(_ zh: Bool, teams: Bool = false) -> String { zh ? (teams ? Names.teams[id] : Names.drivers[id]) ?? name : name }
    public func teamTitle(_ zh: Bool) -> String { zh ? Names.teams[teamID] ?? team : team }
}

public struct Standings: Codable, Sendable {
    public let season: Int
    public let round: Int?
    public let rows: [Standing]
}

public struct Snapshot<Value: Codable>: Codable {
    public let value: Value
    public let fetchedAt: Date
    public init(value: Value, fetchedAt: Date = Date()) { self.value = value; self.fetchedAt = fetchedAt }
}
