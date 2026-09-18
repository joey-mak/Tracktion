import Foundation

/// A sourced reference snapshot, not a live or automatically updated sporting regulation.
public struct CircuitProfile: Codable, Identifiable {
    public let id: String
    public let sourceYear: Int
    public let sourceURL: String
    public let mapURL: String
    public let mapFile: String
    public let sectorsLabeled: Bool
    public let checkedAt: String
    public let length: String
    public let laps: String
    public let distance: String
    public let firstGP: String
    public let historyZH: String
    public let historyEN: String
    public let regionZH: String
    public let regionEN: String
    public func history(_ zh: Bool) -> String { zh ? historyZH : historyEN }
    public func region(_ zh: Bool) -> String { zh ? regionZH : regionEN }
}

public enum CircuitCatalog {
    public static func decode(_ data: Data) throws -> [String: CircuitProfile] {
        let profiles = try JSONDecoder().decode([CircuitProfile].self, from: data)
        var result: [String: CircuitProfile] = [:]
        for profile in profiles {
            guard result[profile.id] == nil,
                  URL(string: profile.sourceURL)?.host == "www.formula1.com",
                  URL(string: profile.mapURL)?.host == "media.formula1.com",
                  let laps = Int(profile.laps), laps > 0,
                  let length = Double(profile.length), length > 0,
                  let distance = Double(profile.distance), distance > 0,
                  !profile.mapFile.contains("/"), !profile.historyZH.isEmpty, !profile.historyEN.isEmpty
            else { throw DataError.invalid }
            result[profile.id] = profile
        }
        return result
    }
    public static let profiles: [String: CircuitProfile] = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "Circuits"),
              let data = try? Data(contentsOf: url), let profiles = try? decode(data) else { return [:] }
        return profiles
    }()
}
