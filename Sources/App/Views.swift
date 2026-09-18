import SwiftUI
import UserNotifications
import WidgetKit

struct RootView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        TabView(selection: $m.tab) {
            NavigationStack { ScheduleView() }.tabItem { Label(m.t("赛历","Schedule"), systemImage:"calendar") }.tag(0)
            NavigationStack { StandingsView() }.tabItem { Label(m.t("积分","Standings"), systemImage:"list.number") }.tag(1)
            NavigationStack { SettingsView() }.tabItem { Label(m.t("设置","Settings"), systemImage:"slider.horizontal.3") }.tag(2)
        }
        .tint(RWStyle.orange)
        .alert(m.t("比赛提醒","Session reminder"), isPresented: Binding(get:{ m.reminderMessage != nil },set:{ if !$0 { m.reminderMessage = nil } })) {
            Button(m.t("知道了","OK")) { m.reminderMessage = nil }
        } message: { Text(m.reminderMessage ?? "") }
    }
}

struct SeasonMenu: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        Menu {
            let current = Calendar.current.component(.year, from:Date())
            ForEach(Array((current-1)...(current+1)), id:\.self) { year in
                Button { m.changeYear(year) } label: { if m.year == year { Label(String(year),systemImage:"checkmark") } else { Text(String(year)) } }
            }
        } label: { HStack(spacing:4) { Text(String(m.year)).monospacedDigit(); Image(systemName:"chevron.down").font(.caption2.bold()) }.font(.subheadline.weight(.semibold)) }
        .disabled(m.loading).accessibilityLabel(m.t("选择赛季","Choose season"))
    }
}

struct RefreshControl: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        if m.loading { ProgressView().accessibilityLabel(m.t("同步中","Refreshing")) }
        else { Button { Task { await m.refresh(force:true) } } label: { Image(systemName:"arrow.clockwise") }.accessibilityLabel(m.t("刷新数据","Refresh data")) }
    }
}

struct ScheduleView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack { Eyebrow(text:"TRACKTION / 比赛周"); Spacer(); SeasonMenu() }
                Picker(m.t("赛历范围","Schedule range"),selection:$m.showSeason) {
                    Text(m.t("本周 / 下一站","This week / Next")).tag(false)
                    Text(m.t("全年赛历","Full season")).tag(true)
                }.pickerStyle(.segmented)
                if m.races == nil {
                    EmptyState(loading:m.loading,failed:m.errors.contains("races"),title:m.t("赛历尚未载入","No schedule yet"))
                } else if let races = m.races?.value, races.isEmpty {
                    EmptyState(loading:false,failed:false,title:m.t("赛历尚未公布","Schedule not published"),detail:m.t("已检查数据源，稍后再来看看。","The source has no schedule for this season yet."))
                } else if let races = m.races?.value {
                    if m.showSeason {
                        HStack { Text(m.t("赛季行程","Season itinerary")).font(.title2.bold()); Spacer(); Text(m.t("\(races.count) 站","\(races.count) rounds")).font(.subheadline).foregroundStyle(.secondary) }
                        ForEach(races) { race in NavigationLink { RaceDetailView(race:race) } label: { RaceRow(race:race) }.buttonStyle(.plain) }
                    } else {
                        TimelineView(.periodic(from:Date(),by:60)) { timeline in
                            let weekly = races.filter { ScheduleLogic.isThisWeek($0,now:timeline.date) }
                            let focus = weekly.first ?? ScheduleLogic.nextRace(races,now:timeline.date)
                            VStack(alignment:.leading,spacing:20) {
                                if let race = focus {
                                    HStack { Text(weekly.isEmpty ? m.t("下一站","Up next") : m.t("比赛周末","Race weekend")).font(.largeTitle.bold()); Spacer(); if weekly.isEmpty { Text(m.t("本周休赛","Off week")).font(.caption.weight(.medium)).foregroundStyle(.secondary) } }
                                    NavigationLink { RaceDetailView(race:race) } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            RaceHero(race:race,now:timeline.date)
                                            Label(m.t("了解赛道 · 地图、历史与目的地", "Explore the circuit · map, history & destination"), systemImage: "arrow.up.right").font(.caption.weight(.semibold)).padding(.horizontal, 6)
                                        }
                                    }.buttonStyle(.plain).accessibilityHint(m.t("打开赛道详情", "Open circuit details"))
                                    HStack { Text(m.t("周末时间表","Weekend schedule")).font(.title2.bold()); Spacer() }
                                    ZoneLabel(race:race)
                                    Panel { VStack(spacing:0) { ForEach(race.sessions) { session in SessionRow(race:race,session:session,now:timeline.date); if session.id != race.sessions.last?.id { Divider().padding(.vertical,7) } } } }
                                    Text(m.t("时间来自公布的赛程，不代表赛事已实际开始或结束。", "Times follow the published schedule, not live session status.")).font(.caption).foregroundStyle(.secondary)
                                } else {
                                    EmptyState(loading:false,failed:false,title:m.t("本赛季赛程已结束","Season schedule complete"),detail:m.t("查看全年赛历，或切换到下一赛季。","Browse the full season or choose next year."))
                                }
                            }
                        }
                    }
                }
                SyncFooter(date:m.races?.fetchedAt,failed:m.errors.contains("races"))
            }.padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(m.t("赛历","Schedule")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.topBarTrailing) { RefreshControl() } }
        .refreshable { await m.refresh(force:true) }
    }
}

struct RaceHero: View {
    @EnvironmentObject var m: AppModel
    let race: Race
    let now: Date
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("ROUND \(String(format:"%02d",race.round))").font(.caption.bold()).tracking(2); Spacer(); if race.isSprint { Text(m.t("冲刺周末","SPRINT WEEKEND")).font(.caption2.bold()).padding(.horizontal,10).padding(.vertical,6).background(.white.opacity(0.14),in:Capsule()) } }.foregroundStyle(.white.opacity(0.75))
            Text(race.title(m.zh)).font(.system(.largeTitle,design:.rounded,weight:.bold)).fixedSize(horizontal:false,vertical:true)
            Text(race.location(m.zh)).font(.subheadline).foregroundStyle(.white.opacity(0.75))
            Text(race.circuitTitle(m.zh)).font(.caption).foregroundStyle(.white.opacity(0.65))
            Rectangle().fill(.white.opacity(0.15)).frame(height:1)
            if let session = race.nextSession(after:now), let start = session.start {
                HStack(alignment:.bottom) {
                    VStack(alignment:.leading,spacing:6) {
                        Text(m.t("接下来 · ","NEXT · ") + session.kind.title(m.zh)).font(.caption.bold()).foregroundStyle(Color.orange)
                        Text(DisplayDate.string(start,zh:m.zh,zone:SharedSettings.zone(for:race))).font(.subheadline.weight(.semibold))
                    }
                    Spacer(minLength:12)
                    VStack(alignment:.trailing,spacing:6) {
                        Text(m.t("距计划开始","STARTS IN")).font(.caption2).foregroundStyle(.white.opacity(0.65))
                        Text(start,style:.relative).font(.system(.headline,design:.rounded)).monospacedDigit()
                    }
                }
            } else { Text(m.t("今日计划时间已到，请查看公布赛程。","Scheduled times have passed. Check published updates.")).font(.subheadline) }
        }
        .padding(22).foregroundStyle(.white)
        .background(LinearGradient(colors:[RWStyle.ink,Color(red:0.14,green:0.20,blue:0.29)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:26))
        .overlay(alignment:.topLeading) { Capsule().fill(RWStyle.orange).frame(width:48,height:4).padding(.leading,22) }
    }
}

struct RaceRow: View {
    @EnvironmentObject var m: AppModel
    let race: Race
    var body: some View {
        Panel {
            HStack(spacing:14) {
                RoundBadge(round:race.round)
                VStack(alignment:.leading,spacing:6) {
                    Text(race.title(m.zh)).font(.headline)
                    Text(race.location(m.zh)).font(.caption).foregroundStyle(.secondary)
                    Text(DisplayDate.dayOnly(race.date,zh:m.zh)).font(.subheadline.weight(.medium)).foregroundStyle(RWStyle.orange)
                }
                Spacer(minLength:2)
                VStack(spacing:8) { if race.isSprint { Text("SPR").font(.caption2.bold()).foregroundStyle(RWStyle.orange) }; Image(systemName:"chevron.right").font(.caption).foregroundStyle(.tertiary) }
            }
        }
    }
}

struct RaceDetailView: View {
    @EnvironmentObject var m: AppModel
    let race: Race
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:20) {
            RaceHero(race:race,now:Date())
            CircuitDetailSections(race: race)
            Text(m.t("周末时间表", "Weekend schedule")).font(.title2.bold())
            ZoneLabel(race:race)
            Panel { VStack { ForEach(race.sessions) { SessionRow(race:race,session:$0,now:Date()); if $0.id != race.sessions.last?.id { Divider() } } } }
            Label(m.t("铃铛：计划开始前 30 分钟提醒", "Bell: remind 30 minutes before scheduled start"),systemImage:"bell").font(.caption).foregroundStyle(.secondary)
        }.padding(20) }.background(Color(.systemGroupedBackground)).navigationTitle(m.t("分站详情","Weekend details")).navigationBarTitleDisplayMode(.inline)
    }
}

struct ZoneLabel: View {
    @EnvironmentObject var m: AppModel
    let race: Race
    var body: some View { Label(m.t("显示时区：", "Time zone: ") + SharedSettings.zone(for:race).identifier,systemImage:"globe.asia.australia").font(.caption).foregroundStyle(.secondary) }
}

struct SessionRow: View {
    @EnvironmentObject var m: AppModel
    let race: Race
    let session: Session
    let now: Date
    var body: some View {
        HStack(spacing:12) {
            Text(session.kind.code).font(.system(.caption,design:.rounded,weight:.bold)).foregroundStyle(session.kind == .race ? RWStyle.orange : .secondary).frame(width:34)
            VStack(alignment:.leading,spacing:5) {
                Text(session.kind.title(m.zh)).font(.subheadline.weight(.semibold))
                if let date = session.start {
                    Text(DisplayDate.string(date,zh:m.zh,zone:SharedSettings.zone(for:race))).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    if date <= now { Text(m.t("计划时间已过","Scheduled time passed")).font(.caption2).foregroundStyle(.tertiary) }
                } else { Text(DisplayDate.dayOnly(session.date,zh:m.zh) + m.t(" · 时间待定"," · Time TBC")).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength:0)
            if let date = session.start, date.timeIntervalSince(now) > 1800 {
                let active = m.reminderIDs.contains(ReminderService.id(race,session))
                Button { Task { await m.toggleReminder(race:race,session:session) } } label: {
                    Image(systemName:active ? "bell.badge.fill" : "bell").foregroundStyle(active ? RWStyle.orange : Color.secondary).frame(width:44,height:44)
                }.buttonStyle(.plain).accessibilityLabel((active ? m.t("取消提醒：","Cancel reminder: ") : m.t("提前30分钟提醒：","Remind 30 minutes before: ")) + session.kind.title(m.zh))
            }
        }.padding(.vertical,8)
    }
}

struct StandingsView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:20) {
            HStack { Eyebrow(text:"CHAMPIONSHIP"); Spacer(); SeasonMenu() }
            Text(m.t("每一分，都算数。","Every point counts.")).font(.largeTitle.bold())
            Picker(m.t("积分榜类型","Standings type"),selection:$m.teams) { Text(m.t("车手","Drivers")).tag(false); Text(m.t("车队","Constructors")).tag(true) }.pickerStyle(.segmented)
            if let snapshot = m.standings {
                if snapshot.value.rows.isEmpty { EmptyState(loading:false,failed:false,title:m.t("暂无已公布积分","No published standings")) }
                else {
                    if let round = snapshot.value.round {
                        Text(m.t("数据源标记：第 \(round) 站", "Source classification: Round \(round)")).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        if let race = m.races?.value.first(where:{$0.round == round}) { Text(race.title(m.zh)).font(.caption).foregroundStyle(.secondary) }
                    }
                    Text(m.t("最新已公布榜单，非比赛中预估积分。冲刺、处罚与更正以数据源更新为准。", "Latest published standings, not live projections. Sprint points and corrections depend on source updates.")).font(.caption).foregroundStyle(.secondary)
                    if let leader = snapshot.value.rows.first {
                        HStack(alignment:.center,spacing:16) {
                            Image(systemName:"laurel.leading").font(.largeTitle).foregroundStyle(RWStyle.orange)
                            VStack(alignment:.leading,spacing:6) { Text(m.t("赛季领先者","CHAMPIONSHIP LEADER")).font(.caption2.bold()).tracking(1); Text(leader.title(m.zh,teams:m.teams)).font(.title2.bold()); if !m.teams { Text(leader.teamTitle(m.zh)).font(.caption).foregroundStyle(.secondary) } }
                            Spacer(minLength:0)
                            VStack(alignment:.trailing,spacing:2) { Text(leader.points).font(.system(.largeTitle,design:.rounded,weight:.bold)); Text(m.t("积分","PTS")).font(.caption).foregroundStyle(.secondary) }
                        }.padding(20).background(RWStyle.orange.opacity(0.09),in:RoundedRectangle(cornerRadius:22))
                    }
                    Panel {
                        VStack(spacing:0) {
                            HStack { Text(m.t("排名 / 参赛者","POS / COMPETITOR")); Spacer(); Text(m.t("积分","PTS")) }.font(.caption2.bold()).foregroundStyle(.secondary).padding(.bottom,12)
                            ForEach(snapshot.value.rows) { row in
                                HStack(spacing:12) {
                                    Text(row.position).font(.system(.subheadline,design:.rounded,weight:.bold)).foregroundStyle(.secondary).frame(minWidth:24,alignment:.leading)
                                    Capsule().fill(RWStyle.team(row.teamID)).frame(width:3,height:30)
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(row.title(m.zh,teams:m.teams)).font(.subheadline.weight(.semibold))
                                        Text(m.teams ? m.t("\(row.wins) 场胜利","\(row.wins) wins") : row.teamTitle(m.zh)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength:4)
                                    Text(row.points).font(.system(.headline,design:.rounded)).monospacedDigit()
                                }.padding(.vertical,12)
                                if row.id != snapshot.value.rows.last?.id { Divider() }
                            }
                        }
                    }
                }
            } else { EmptyState(loading:m.loading,failed:m.errors.contains(m.standingsKey),title:m.t("积分尚未载入","Standings not loaded")) }
            SyncFooter(date:m.standings?.fetchedAt,failed:m.errors.contains(m.standingsKey))
        }.padding(20) }
        .background(Color(.systemGroupedBackground)).navigationTitle(m.t("积分","Standings")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.topBarTrailing) { RefreshControl() } }.refreshable { await m.refresh(force:true) }
    }
}

struct SyncFooter: View {
    @EnvironmentObject var m: AppModel
    let date: Date?
    let failed: Bool
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            if failed { Label(date == nil ? m.t("连接失败，请稍后刷新。","Connection failed. Try again later.") : m.t("更新失败，正在显示已缓存数据。","Refresh failed. Showing saved data."),systemImage:"wifi.exclamationmark").foregroundStyle(.orange) }
            if m.cacheWarning { Text(m.t("本次数据未能保存到本机。","Could not save this update for offline use.")).foregroundStyle(.orange) }
            if let date { Text(m.t("最近同步：","Last checked: ") + DisplayDate.string(date,zh:m.zh)) }
            Text(m.t("数据：Jolpica · 独立、非官方车迷应用","Data: Jolpica · Independent, unofficial fan app"))
        }.font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct EmptyState: View {
    @EnvironmentObject var m: AppModel
    let loading: Bool
    let failed: Bool
    let title: String
    var detail: String? = nil
    var body: some View {
        VStack(spacing:16) {
            if loading { ProgressView().scaleEffect(1.3) } else { Image(systemName:failed ? "wifi.exclamationmark" : "calendar.badge.clock").font(.system(size:36)).foregroundStyle(RWStyle.orange) }
            Text(loading ? m.t("正在同步赛事数据…","Fetching race data…") : title).font(.headline)
            if let detail, !loading { Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            if failed && !loading { Button(m.t("重新加载","Try again")) { Task { await m.refresh(force:true) } }.buttonStyle(.bordered) }
        }.frame(maxWidth:.infinity).padding(.vertical,50)
    }
}

struct SettingsView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        Form {
            Section {
                VStack(alignment:.leading,spacing:8) { Text(m.t("比赛周","Tracktion")).font(.largeTitle.bold()); Text(m.t("属于你的比赛周末。","Your race weekend, at a glance.")).foregroundStyle(.secondary); Text("0.2 · PERSONAL EDITION").font(.caption2.bold()).tracking(1.5).foregroundStyle(RWStyle.orange) }.padding(.vertical,12)
            }
            Section(m.t("偏好","Preferences")) {
                Picker(m.t("语言","Language"),selection:$m.language) { Text(m.t("跟随系统","System")).tag("system"); Text("简体中文").tag("zh"); Text("English").tag("en") }
                Picker(m.t("赛程时区","Schedule time zone"),selection:$m.zoneMode) { Text(m.t("手机当地时间","Device local time")).tag("local"); Text(m.t("赛道当地时间","Circuit local time")).tag("track") }
                Picker(m.t("外观","Appearance"),selection:$m.appearance) { Text(m.t("跟随系统","System")).tag("system"); Text(m.t("浅色","Light")).tag("light"); Text(m.t("深色","Dark")).tag("dark") }
            }
            Section(m.t("比赛提醒","Session reminders")) {
                Text(m.t("点击场次旁的铃铛，在计划开始前 30 分钟提醒。赛程同步时会更新已设置的提醒。", "Tap a session bell for a reminder 30 minutes before its scheduled start. Saved reminders are adjusted when the schedule syncs.")).font(.subheadline)
                HStack { Text(m.t("已设置","Scheduled")); Spacer(); Text("\(m.reminderIDs.count)").foregroundStyle(.secondary) }
                Button(m.t("取消所有比赛提醒","Cancel all session reminders"),role:.destructive) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:Array(m.reminderIDs)); Task { await m.loadReminders() } }.disabled(m.reminderIDs.isEmpty)
            }
            Section(m.t("桌面小组件","Home Screen widgets")) {
                Label(m.t("下一场次与周末赛程","Next session & weekend schedule"),systemImage:"calendar")
                Label(m.t("车手或车队积分","Driver or constructor standings"),systemImage:"list.number")
                Text(m.t("长按手机桌面 → 编辑 → 添加小组件 → 比赛周。分别提供赛历、车手积分与车队积分组件。刷新由 iOS 调度，不保证即时更新。", "Touch and hold the Home Screen → Edit → Add Widget → Tracktion. Choose the schedule, drivers, or constructors widget. iOS schedules refreshes; updates are not instantaneous.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(m.t("数据与隐私","Data & privacy")) {
                Text(m.t("无账号、无广告、无分析 SDK。偏好和缓存保存在设备上。获取数据时，Jolpica 会收到必要的网络请求及 IP 地址。", "No account, ads or analytics SDKs. Preferences and cache stay on your device. Jolpica receives network requests and your IP address when fetching data.")).font(.subheadline)
                Link(m.t("Jolpica 数据来源与条款","Jolpica data & terms"),destination:URL(string:"https://github.com/jolpica/jolpica-f1/blob/main/TERMS.md")!)
                Link("CC BY-NC-SA 4.0",destination:URL(string:"https://creativecommons.org/licenses/by-nc-sa/4.0/")!)
                Text(m.t("本应用仅供非商业使用，与 Formula 1、FIA、车队及车手无关联。积分以数据源公布为准，可能滞后于比赛及赛后裁决。中文名称为本应用提供的显示翻译，未知名称保留原文。", "For non-commercial use. Not affiliated with Formula 1, the FIA, teams or drivers. Standings follow the data source and may lag races or decisions. Chinese display translations are provided by this app; unknown names retain source spelling.")).font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle(m.t("设置","Settings"))
    }
}
