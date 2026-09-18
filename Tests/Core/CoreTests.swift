import XCTest
@testable import RaceWeekCore

final class CoreTests: XCTestCase {
    func testMalaysiaRaceTranslationKeepsEventAndVenueDistinct() {
        let race = Race(season: 2026, round: 16, name: "Bahrain Grand Prix in Malaysia", circuitID: "sepang", circuit: "Sepang International Circuit", city: "Kuala Lumpur", country: "Malaysia", date: "2026-10-04", sessions: [])
        XCTAssertEqual(race.title(true), "巴林大奖赛（马来西亚）")
        XCTAssertEqual(race.title(false), "Bahrain Grand Prix in Malaysia")
        XCTAssertEqual(race.circuitTitle(true), "雪邦国际赛道")
        XCTAssertEqual(race.trackZone?.identifier, "Asia/Kuala_Lumpur")
    }
    func testBundledCircuitCatalogSourcesAndAssets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Resources/Circuits")
        let profiles = try CircuitCatalog.decode(Data(contentsOf: directory.appendingPathComponent("catalog.json")))
        XCTAssertEqual(profiles.count, 26)
        XCTAssertEqual(profiles["sepang"]?.length, "5.543")
        XCTAssertEqual(profiles["sepang"]?.laps, "56")
        XCTAssertEqual(profiles["bahrain"]?.length, "5.412")
        XCTAssertNotEqual(profiles["sepang"]?.mapFile, profiles["bahrain"]?.mapFile)
        for p in profiles.values {
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(p.mapFile).path), p.id)
            XCTAssertFalse(p.regionZH.isEmpty, p.id)
            XCTAssertFalse(p.regionEN.isEmpty, p.id)
            XCTAssertTrue([2025,2026].contains(p.sourceYear))
        }
    }
    func testCatalogRejectsDuplicateCircuitAndNonOfficialSource() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Circuits/catalog.json"))
        var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertThrowsError(try CircuitCatalog.decode(JSONSerialization.data(withJSONObject: [rows[0],rows[0]])))
        rows[0]["sourceURL"] = "https://example.com/circuit"
        XCTAssertThrowsError(try CircuitCatalog.decode(JSONSerialization.data(withJSONObject: rows)))
    }
    func testMissingTimeDoesNotInventMidnight() {
        XCTAssertNil(Session(kind: .race, date: "2026-09-26", time: nil).start)
        XCTAssertNil(RaceDate.parse("2026-09-26", time: "TBC"))
    }
    func testUTCConvertsAcrossDayBoundary() throws {
        let date = try XCTUnwrap(RaceDate.parse("2026-09-26", time: "23:00:00Z"))
        XCTAssertEqual(RaceDate.dayString(date, zone: TimeZone(identifier: "Asia/Shanghai")!), "2026-09-27")
        XCTAssertEqual(RaceDate.dayString(date, zone: TimeZone(identifier: "America/Los_Angeles")!), "2026-09-26")
    }
    let raceJSON = #"{"MRData":{"RaceTable":{"season":"2026","Races":[{"season":"2026","round":"1","raceName":"Example Grand Prix","Circuit":{"circuitId":"example","circuitName":"Example Circuit","Location":{"locality":"Example","country":"Example"}},"date":"2026-09-26","SprintShootout":{"date":"2026-09-25","time":"10:00:00Z"},"Sprint":{"date":"2026-09-26","time":"08:00:00Z"}}]}}}"#
    func testSprintAliasAndUnknownRaceTime() throws {
        let races = try Jolpica.decodeRaces(Data(raceJSON.utf8), year: 2026)
        XCTAssertEqual(races[0].sessions.map(\.kind), [.sprintQualifying,.sprint,.race])
        XCTAssertTrue(races[0].isSprint)
        XCTAssertNil(races[0].sessions.last!.start)
        XCTAssertEqual(races[0].title(true), "Example Grand Prix")
        XCTAssertThrowsError(try Jolpica.decodeRaces(Data(raceJSON.utf8), year: 2027))
    }
    func testEmptyStandingsAndFractionalPoints() throws {
        let empty = #"{"MRData":{"StandingsTable":{"season":"2027","StandingsLists":[]}}}"#
        XCTAssertTrue(try Jolpica.decodeStandings(Data(empty.utf8), year: 2027, teams: false).rows.isEmpty)
        let json = #"{"MRData":{"StandingsTable":{"season":"2026","StandingsLists":[{"season":"2026","round":"1","ConstructorStandings":[{"position":"1","points":"12.5","wins":"0","Constructor":{"constructorId":"example","name":"Example"}}]}]}}}"#
        let result = try Jolpica.decodeStandings(Data(json.utf8), year: 2026, teams: true)
        XCTAssertEqual(result.rows[0].points,"12.5")
        XCTAssertEqual(result.round,1)
    }
    func testFreshnessRejectsOldAndFutureTimestamps() {
        let now = Date()
        XCTAssertTrue(Cache.fresh(now.addingTimeInterval(-10),now:now))
        XCTAssertFalse(Cache.fresh(now.addingTimeInterval(-901),now:now))
        XCTAssertFalse(Cache.fresh(now.addingTimeInterval(10),now:now))
    }
}
