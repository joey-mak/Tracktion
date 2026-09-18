import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum DataError: Error { case response(Int), invalid, seasonMismatch }

public enum Jolpica {
    public static let base = "https://api.jolpi.ca/ergast/f1"
    public static func fetch(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(base)/\(path)/?limit=100") else { throw DataError.invalid }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("Tracktion/0.2 (personal non-commercial iOS companion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw DataError.invalid }
        guard response.statusCode == 200 else { throw DataError.response(response.statusCode) }
        return data
    }
    public static func races(_ year: Int) async throws -> [Race] { try decodeRaces(await fetch("\(year)/races"), year: year) }
    public static func standings(_ year: Int, teams: Bool) async throws -> Standings { try decodeStandings(await fetch("\(year)/\(teams ? "constructorstandings" : "driverstandings")"), year: year, teams: teams) }

    public static func decodeRaces(_ data: Data, year: Int) throws -> [Race] {
        let root = try JSONDecoder().decode(RaceEnvelope.self, from: data).MRData.RaceTable
        guard root.season == String(year) else { throw DataError.seasonMismatch }
        return try root.Races.map { r in
            guard let season = Int(r.season), season == year, let round = Int(r.round), RaceDate.day(r.date) != nil else { throw DataError.invalid }
            var sessions: [Session] = []
            let fields: [(SessionKind, TimeField?)] = [(.fp1,r.FirstPractice),(.fp2,r.SecondPractice),(.fp3,r.ThirdPractice),(.sprintQualifying,r.SprintQualifying ?? r.SprintShootout),(.sprint,r.Sprint),(.qualifying,r.Qualifying)]
            for (kind, field) in fields { if let field { sessions.append(Session(kind: kind, date: field.date, time: field.time)) } }
            sessions.append(Session(kind: .race, date: r.date, time: r.time))
            sessions.sort { a,b in a.date == b.date ? (a.start ?? .distantFuture) < (b.start ?? .distantFuture) : a.date < b.date }
            return Race(season: season, round: round, name: r.raceName, circuitID: r.Circuit.circuitId, circuit: r.Circuit.circuitName, city: r.Circuit.Location.locality, country: r.Circuit.Location.country, date: r.date, sessions: sessions)
        }.sorted { $0.round < $1.round }
    }
    public static func decodeStandings(_ data: Data, year: Int, teams: Bool) throws -> Standings {
        let table = try JSONDecoder().decode(StandingsEnvelope.self, from: data).MRData.StandingsTable
        guard table.season == String(year) else { throw DataError.seasonMismatch }
        guard let list = table.StandingsLists.first else { return Standings(season: year, round: nil, rows: []) }
        guard list.season == String(year) else { throw DataError.seasonMismatch }
        let rows: [Standing]
        if teams {
            guard let entries = list.ConstructorStandings else { throw DataError.invalid }
            rows = entries.map { .init(id: $0.Constructor.constructorId, position: $0.positionText ?? $0.position, name: $0.Constructor.name, code: "", teamID: $0.Constructor.constructorId, team: $0.Constructor.name, points: $0.points, wins: $0.wins) }
        } else {
            guard let entries = list.DriverStandings else { throw DataError.invalid }
            rows = entries.map { .init(id: $0.Driver.driverId, position: $0.positionText ?? $0.position, name: "\($0.Driver.givenName) \($0.Driver.familyName)", code: $0.Driver.code ?? String($0.Driver.familyName.prefix(3)).uppercased(), teamID: $0.Constructors.last?.constructorId ?? "", team: $0.Constructors.map(\.name).joined(separator: " / "), points: $0.points, wins: $0.wins) }
        }
        // Preserve provider order, including equal points and non-numeric classifications.
        return Standings(season: year, round: Int(list.round), rows: rows)
    }
}

private struct TimeField: Decodable { let date: String; let time: String? }
private struct CircuitDTO: Decodable { let circuitId: String; let circuitName: String; let Location: LocationDTO }
private struct LocationDTO: Decodable { let locality: String; let country: String }
private struct RaceDTO: Decodable {
    let season: String; let round: String; let raceName: String; let Circuit: CircuitDTO; let date: String; let time: String?
    let FirstPractice: TimeField?; let SecondPractice: TimeField?; let ThirdPractice: TimeField?; let Qualifying: TimeField?; let Sprint: TimeField?; let SprintQualifying: TimeField?; let SprintShootout: TimeField?
}
private struct RaceEnvelope: Decodable { let MRData: Body; struct Body: Decodable { let RaceTable: Table }; struct Table: Decodable { let season: String; let Races: [RaceDTO] } }
private struct TeamDTO: Decodable { let constructorId: String; let name: String }
private struct DriverDTO: Decodable { let driverId: String; let givenName: String; let familyName: String; let code: String? }
private struct DriverRowDTO: Decodable { let position: String; let positionText: String?; let points: String; let wins: String; let Driver: DriverDTO; let Constructors: [TeamDTO] }
private struct TeamRowDTO: Decodable { let position: String; let positionText: String?; let points: String; let wins: String; let Constructor: TeamDTO }
private struct StandingsEnvelope: Decodable {
    let MRData: Body
    struct Body: Decodable { let StandingsTable: Table }
    struct Table: Decodable { let season: String; let StandingsLists: [ListDTO] }
    struct ListDTO: Decodable { let season: String; let round: String; let DriverStandings: [DriverRowDTO]?; let ConstructorStandings: [TeamRowDTO]? }
}
