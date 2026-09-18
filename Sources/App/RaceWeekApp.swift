import SwiftUI
import WidgetKit
import UserNotifications

@main
struct RaceWeekApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .environment(\.locale, Locale(identifier: model.zh ? "zh_Hans" : "en"))
                .preferredColorScheme(model.appearance == "dark" ? .dark : model.appearance == "light" ? .light : nil)
                .task { await model.refresh() }
                .onChange(of: phase) { _, value in if value == .active { Task { await model.refresh() } } }
                .onOpenURL { url in if url.host == "standings" { model.tab = 1 } else { model.tab = 0; model.showSeason = false } }
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var year = Calendar.current.component(.year, from: Date())
    @Published var tab = 0
    @Published var showSeason = false
    @Published var teams = false
    @Published var language = SharedSettings.language { didSet { SharedSettings.language = language; WidgetCenter.shared.reloadAllTimelines() } }
    @Published var zoneMode = SharedSettings.zoneMode { didSet { SharedSettings.zoneMode = zoneMode; WidgetCenter.shared.reloadAllTimelines() } }
    @Published var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "system" { didSet { UserDefaults.standard.set(appearance, forKey: "appearance") } }
    @Published var races: Snapshot<[Race]>?
    @Published var drivers: Snapshot<Standings>?
    @Published var constructors: Snapshot<Standings>?
    @Published var loading = false
    @Published var errors: Set<String> = []
    @Published var cacheWarning = false
    @Published var reminderIDs: Set<String> = []
    @Published var reminderMessage: String?
    private var lastAttempt: Date?
    var zh: Bool { language == "zh" || (language == "system" && (Locale.preferredLanguages.first ?? "").hasPrefix("zh")) }
    func t(_ zh: String, _ en: String) -> String { self.zh ? zh : en }
    var standings: Snapshot<Standings>? { teams ? constructors : drivers }
    var standingsKey: String { teams ? "teams" : "drivers" }
    init() { loadCache() }
    func loadCache() {
        races = Cache.read([Race].self, key: Cache.key(year,"races"))
        drivers = Cache.read(Standings.self, key: Cache.key(year,"drivers"))
        constructors = Cache.read(Standings.self, key: Cache.key(year,"teams"))
    }
    func changeYear(_ year: Int) {
        guard !loading else { return }
        self.year = year; errors = []; lastAttempt = nil; loadCache()
        Task { await refresh() }
    }
    func refresh(force: Bool = false) async {
        guard !loading else { return }
        // A manual refresh is throttled too: do not exhaust the shared public service.
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < 15 { return }
        if !force, let r = races, let d = drivers, let c = constructors,
           [r.fetchedAt,d.fetchedAt,c.fetchedAt].allSatisfy({ Cache.fresh($0) }) { await loadReminders(); return }
        loading = true; lastAttempt = Date(); errors = []; cacheWarning = false
        defer { loading = false; WidgetCenter.shared.reloadAllTimelines() }
        do {
            let value = Snapshot(value: try await Jolpica.races(year)); races = value
            do { try Cache.save(value, key: Cache.key(year,"races")) } catch { cacheWarning = true }
            await ReminderService.reconcile(value.value, zh: zh)
        } catch { errors.insert("races") }
        do {
            let value = Snapshot(value: try await Jolpica.standings(year, teams: false)); drivers = value
            do { try Cache.save(value, key: Cache.key(year,"drivers")) } catch { cacheWarning = true }
        } catch { errors.insert("drivers") }
        do {
            let value = Snapshot(value: try await Jolpica.standings(year, teams: true)); constructors = value
            do { try Cache.save(value, key: Cache.key(year,"teams")) } catch { cacheWarning = true }
        } catch { errors.insert("teams") }
        await loadReminders()
    }
    func loadReminders() async { reminderIDs = Set(await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)) }
    func toggleReminder(race: Race, session: Session) async {
        let id = ReminderService.id(race, session)
        if reminderIDs.contains(id) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]); await loadReminders(); return }
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound])
            guard allowed else { reminderMessage = t("通知未获允许。请在 iPhone 设置中为比赛周开启通知。", "Notifications are disabled. Enable them for Tracktion in iPhone Settings."); return }
            guard reminderIDs.count < 48 else { reminderMessage = t("最多设置 48 个提醒，请先取消一些。", "You can set up to 48 reminders. Remove one first."); return }
            try await ReminderService.add(race, session, zh: zh)
            await loadReminders()
        } catch { reminderMessage = t("提醒未能添加。请检查开赛时间是否超过 30 分钟。", "Could not add reminder. The session must be more than 30 minutes away.") }
    }
}

enum ReminderService {
    static func id(_ race: Race, _ session: Session) -> String { "rw-\(race.id)-\(session.id)" }
    static func add(_ race: Race, _ session: Session, zh: Bool) async throws {
        guard let start = session.start, start.timeIntervalSinceNow > 1800 else { throw DataError.invalid }
        let content = UNMutableNotificationContent()
        content.title = race.title(zh)
        content.body = zh ? "\(session.kind.title(true))计划在 30 分钟后开始。" : "\(session.kind.title(false)) is scheduled to start in 30 minutes."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: start.timeIntervalSinceNow - 1800, repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id(race,session), content: content, trigger: trigger))
    }
    static func reconcile(_ races: [Race], zh: Bool) async {
        guard let season = races.first?.season else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("rw-\(season)-") }
        let map = Dictionary(uniqueKeysWithValues: races.flatMap { r in r.sessions.map { (id(r,$0),(r,$0)) } })
        for request in pending {
            if let (race,session) = map[request.identifier], let date = session.start, date.timeIntervalSinceNow > 1800 {
                try? await add(race,session,zh:zh)
            } else { center.removePendingNotificationRequests(withIdentifiers: [request.identifier]) }
        }
    }
}
