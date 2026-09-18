import SwiftUI
import WidgetKit

struct RaceEntry: TimelineEntry {
    let date: Date
    let races: Snapshot<[Race]>?
    let standings: Snapshot<Standings>?
    let failed: Bool
    var race: Race? { races.flatMap { ScheduleLogic.nextRace($0.value, now: date) } }
}

struct RaceProvider: TimelineProvider {
    let kind: String
    func placeholder(in context: Context) -> RaceEntry { RaceEntry(date: Date(), races: nil, standings: nil, failed: false) }
    func getSnapshot(in context: Context, completion: @escaping (RaceEntry) -> Void) { completion(cached()) }
    func cached() -> RaceEntry {
        let year = Calendar.current.component(.year, from: Date())
        return RaceEntry(date: Date(), races: Cache.read([Race].self, key: Cache.key(year,"races")), standings: Cache.read(Standings.self, key: Cache.key(year,kind)), failed: false)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RaceEntry>) -> Void) {
        Task {
            let year = Calendar.current.component(.year, from: Date())
            var entry = cached()
            do {
                if kind == "races" {
                    if entry.races.map({ Cache.fresh($0.fetchedAt, seconds: 1800) }) != true {
                        let value = Snapshot(value: try await Jolpica.races(year))
                        try? Cache.save(value, key: Cache.key(year,kind))
                        entry = RaceEntry(date: Date(), races: value, standings: nil, failed: false)
                    }
                } else if entry.standings.map({ Cache.fresh($0.fetchedAt, seconds: 1800) }) != true {
                    let value = Snapshot(value: try await Jolpica.standings(year, teams: kind == "teams"))
                    try? Cache.save(value, key: Cache.key(year,kind))
                    entry = RaceEntry(date: Date(), races: nil, standings: value, failed: false)
                }
            } catch { entry = RaceEntry(date: Date(), races: entry.races, standings: entry.standings, failed: true) }
            // Precompute session boundaries; actual network refresh remains controlled by iOS.
            var entries = [entry]
            if kind == "races", let races = entry.races {
                let dates = races.value.flatMap(\.sessions).compactMap(\.start).filter { $0 > entry.date && $0 < entry.date.addingTimeInterval(86400) }.sorted()
                for date in dates { entries.append(RaceEntry(date: date.addingTimeInterval(1), races: races, standings: nil, failed: entry.failed)) }
            }
            completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(1800))))
        }
    }
}

struct RaceWidgetView: View {
    let entry: RaceEntry
    let kind: String
    @Environment(\.widgetFamily) var family
    var zh: Bool { SharedSettings.chinese }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(zh ? "比赛周" : "TRACKTION").font(.caption2.bold()).tracking(1).foregroundStyle(RWStyle.orange)
                Spacer()
                Text(kind == "races" ? (zh ? "赛程" : "SCHEDULE") : (zh ? "积分" : "POINTS")).font(.caption2).foregroundStyle(.secondary)
            }
            if kind == "races", let race = entry.race {
                Text(race.title(zh)).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                if let session = race.nextSession(after: entry.date), let start = session.start {
                    Text(session.kind.title(zh)).font(.caption).foregroundStyle(.secondary)
                    Text(DisplayDate.string(start, zh: zh, zone: SharedSettings.zone(for: race))).font(.caption.bold())
                    if family == .systemMedium {
                        Text(SharedSettings.zone(for: race).identifier).font(.caption2).foregroundStyle(.secondary)
                        Text(start, style: .relative).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(RWStyle.orange)
                    }
                } else { Text(zh ? "本日赛程已到计划时间" : "Scheduled sessions have started").font(.caption) }
                Spacer(minLength: 0)
                stamp(entry.races?.fetchedAt)
            } else if kind != "races", let table = entry.standings?.value, !table.rows.isEmpty {
                Text("\(table.season.description) · " + (zh ? "第 \(table.round ?? 0) 轮后" : "After round \(table.round ?? 0)")).font(.caption2).foregroundStyle(.secondary)
                ForEach(Array(table.rows.prefix(3))) { row in
                    HStack(spacing: 6) {
                        Text(row.position).foregroundStyle(RWStyle.orange).frame(width: 14)
                        Text(row.title(zh, teams: kind == "teams")).lineLimit(1).minimumScaleFactor(0.65)
                        Spacer(minLength: 2)
                        Text(row.points).monospacedDigit().bold()
                    }.font(.caption)
                }
                Spacer(minLength: 0)
                stamp(entry.standings?.fetchedAt)
            } else {
                Spacer()
                Text(zh ? "暂无已发布数据" : "No published data").font(.headline)
                Text(zh ? "轻点打开 App 查看" : "Tap to open Tracktion").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .environment(\.locale, Locale(identifier: zh ? "zh_Hans" : "en"))
        .widgetURL(URL(string: kind == "races" ? "raceweek://schedule" : "raceweek://standings"))
    }
    @ViewBuilder func stamp(_ date: Date?) -> some View {
        if let date {
            HStack(spacing: 3) {
                Text(entry.failed ? (zh ? "缓存" : "Cached") : (zh ? "获取于" : "Fetched"))
                Text(date, style: .date)
                Text(date, style: .time)
            }.font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

struct ScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaceWeekSchedule", provider: RaceProvider(kind: "races")) { RaceWidgetView(entry: $0, kind: "races") }
            .configurationDisplayName("赛历 / Schedule").description("下一场赛程与计划时间 · Next scheduled session")
            .supportedFamilies([.systemSmall,.systemMedium])
    }
}
struct DriversWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaceWeekDrivers", provider: RaceProvider(kind: "drivers")) { RaceWidgetView(entry: $0, kind: "drivers") }
            .configurationDisplayName("车手积分 / Drivers").description("已公布积分前三名 · Published top three")
            .supportedFamilies([.systemSmall,.systemMedium])
    }
}
struct TeamsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaceWeekTeams", provider: RaceProvider(kind: "teams")) { RaceWidgetView(entry: $0, kind: "teams") }
            .configurationDisplayName("车队积分 / Teams").description("已公布积分前三名 · Published top three")
            .supportedFamilies([.systemSmall,.systemMedium])
    }
}
@main struct RaceWeekWidgets: WidgetBundle {
    var body: some Widget { ScheduleWidget(); DriversWidget(); TeamsWidget() }
}
