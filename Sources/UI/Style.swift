import SwiftUI

enum RWStyle {
    static let orange = Color(red: 0.96, green: 0.36, blue: 0.12)
    static let ink = Color(red: 0.065, green: 0.09, blue: 0.14)
    static func team(_ id: String) -> Color {
        switch id {
        case "mercedes": .teal
        case "ferrari": .red
        case "mclaren": .orange
        case "red_bull": .blue
        case "aston_martin": .green
        case "alpine": .pink
        case "williams": .cyan
        case "audi", "sauber": .green
        default: .secondary
        }
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)) }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(.secondary) }
}

struct RoundBadge: View {
    let round: Int
    var body: some View { Text(String(format: "%02d",round)).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(RWStyle.orange).frame(width:46,height:46).background(RWStyle.orange.opacity(0.1), in: RoundedRectangle(cornerRadius:14)) }
}

enum DisplayDate {
    static func string(_ date: Date, zh: Bool, zone: TimeZone = .current, template: String = "MMMdEEEHHmm") -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: zh ? "zh_CN" : "en_GB"); f.timeZone = zone; f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from:date)
    }
    static func dayOnly(_ source: String, zh: Bool) -> String {
        guard let day = RaceDate.day(source) else { return source }
        return string(day,zh:zh,zone:TimeZone(secondsFromGMT:0)!,template:"MMMdEEE")
    }
}
