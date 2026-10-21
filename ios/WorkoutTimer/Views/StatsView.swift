import SwiftUI

struct StatsSummary {
    struct Favorite: Identifiable {
        let id: String
        let config: WorkoutConfig
        var count: Int
    }

    var count = 0
    var streak = 0
    var weekMinutes = 0
    var goal = 60
    var totalActive = 0
    var weekDays = 0
    var daysSoFar = 1
    var doneRate = 0.0
    var moveRate = 0.0
    var average = 0.0
    var averageRatio = 0.0
    var dailyMinutes: [Double] = []
    var dayLabels: [String] = []
    var favorites: [Favorite] = []

    var totalText: String {
        let h = totalActive / 3600
        let m = Int((Double(totalActive % 3600) / 60).rounded())
        return h > 0 ? "\(h) 時 \(m) 分" : "\(m) 分"
    }

    init(list: [WorkoutRecord], goal: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sinceMonday = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -sinceMonday, to: today) ?? today
        let week = list.filter { $0.startedAt >= monday }

        self.goal = max(1, goal)
        count = list.count
        weekMinutes = Int((Double(week.reduce(0) { $0 + $1.activeSec }) / 60).rounded())
        weekDays = Set(week.map { cal.startOfDay(for: $0.startedAt) }).count
        daysSoFar = sinceMonday + 1

        let days = Set(list.map { cal.startOfDay(for: $0.startedAt) })
        var d = days.contains(today) ? today : (cal.date(byAdding: .day, value: -1, to: today) ?? today)
        while days.contains(d) {
            streak += 1
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d.addingTimeInterval(-86400)
        }

        totalActive = list.reduce(0) { $0 + $1.activeSec }
        if !list.isEmpty {
            doneRate = Double(list.filter { $0.completed }.count) / Double(list.count)
            average = Double(totalActive) / Double(list.count)
            let planned = Double(list.reduce(0) { $0 + $1.plannedSec }) / Double(list.count)
            averageRatio = planned > 0 ? average / planned : 0
        }
        let movesDone = list.reduce(0) { $0 + $1.workDone }
        let movesTotal = list.reduce(0) { $0 + $1.workTotal }
        moveRate = movesTotal > 0 ? Double(movesDone) / Double(movesTotal) : 0

        for k in stride(from: 6, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -k, to: today) ?? today
            let secs = list.filter { cal.isDate($0.startedAt, inSameDayAs: day) }.reduce(0) { $0 + $1.activeSec }
            dailyMinutes.append(Double(secs) / 60)
            dayLabels.append(k == 0 ? "今天" : "週" + Fmt.weekday(day))
        }

        var counts: [String: Favorite] = [:]
        var order: [String] = []
        for r in list {
            let key = r.config.key
            if counts[key] == nil {
                counts[key] = Favorite(id: key, config: r.config, count: 0)
                order.append(key)
            }
            counts[key]?.count += 1
        }
        favorites = order.compactMap { counts[$0] }.sorted { $0.count > $1.count }.prefix(3).map { $0 }
    }
}

struct StatsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let s = StatsSummary(list: store.displayHistory, goal: store.settings.weeklyGoal)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: "統計數據",
                          subtitle: store.hasHistory ? "本週與累積的鍛鍊成果" : "範例資料，完成鍛鍊後換成你的數字")
                if !store.hasHistory {
                    NoteView("以下是範例資料。完成第一次鍛鍊後，統計會換成你自己的數字。").padding(.top, 16)
                }
                hero(s).padding(.top, 22)
                smallRings(s).padding(.top, 28)
                Panel(title: "近 7 天運動分鐘") {
                    WeekChart(values: s.dailyMinutes, labels: s.dayLabels)
                }
                .padding(.top, 22)
                Panel(title: "最常用的組合") {
                    VStack(spacing: 0) {
                        ForEach(Array(s.favorites.enumerated()), id: \.offset) { i, f in
                            if i > 0 { Rectangle().fill(Palette.line).frame(height: 1.5) }
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Fmt.clock(f.config.sanitized.totalSeconds))
                                        .font(.num(16, .bold))
                                        .foregroundStyle(Palette.fg)
                                    Text(f.config.summary)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Palette.muted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Text("\(f.count) 次")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Palette.orange)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.top, 14)
            }
            .pageContent()
        }
        .scrollIndicators(.hidden)
        .background(PageBackground())
    }

    private func hero(_ s: StatsSummary) -> some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(fraction: Double(s.weekMinutes) / Double(s.goal), color: Palette.blue, lineWidth: 12)
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(s.weekMinutes)").font(.num(34, .heavy))
                        Text("分").font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Palette.fg)
                    Text("本週運動\n目標 \(s.goal) 分鐘")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 166, height: 166)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 14) {
                LegendRow(icon: "bolt.fill", color: Palette.orange, value: "\(s.count)", label: "鍛鍊次數")
                LegendRow(icon: "flame.fill", color: Palette.orange, value: "\(s.streak) 天", label: "連續鍛鍊")
                LegendRow(icon: "clock.fill", color: Palette.orange, value: s.totalText, label: "累積運動時間")
            }
            Spacer(minLength: 0)
        }
    }

    private func smallRings(_ s: StatsSummary) -> some View {
        HStack(spacing: 8) {
            SmallRing(fraction: Double(s.weekDays) / Double(max(1, s.daysSoFar)), color: Palette.mustard, ink: Palette.mustardInk,
                      value: "\(s.weekDays)", unit: "/\(s.daysSoFar) 天", label: "本週活躍")
            SmallRing(fraction: s.doneRate, color: Palette.orange, ink: Palette.orange,
                      value: "\(Int((s.doneRate * 100).rounded()))%", unit: "", label: "完成率")
            SmallRing(fraction: s.moveRate, color: Palette.greenSolid, ink: Palette.greenInk,
                      value: "\(Int((s.moveRate * 100).rounded()))%", unit: "", label: "動作完成")
            SmallRing(fraction: s.averageRatio, color: Palette.blue, ink: Palette.blueInk,
                      value: Fmt.clock(Int(s.average.rounded())), unit: "", label: "平均時長")
        }
    }
}

struct SmallRing: View {
    let fraction: Double
    let color: Color
    let ink: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ProgressRing(fraction: fraction, color: color, lineWidth: 6)
                VStack(spacing: 0) {
                    Text(value)
                        .font(.num(14, .bold))
                        .foregroundStyle(Palette.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !unit.isEmpty {
                        Text(unit).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
                    }
                }
                .padding(9)
            }
            .frame(width: 72, height: 72)
            Text(label).font(.system(size: 13, weight: .bold)).foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct WeekChart: View {
    let values: [Double]
    let labels: [String]

    static func niceMax(_ v: Double) -> Int {
        for step in [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240] where v <= Double(step) {
            return step
        }
        return Int(ceil(v / 60) * 60)
    }

    private func label(_ v: Double) -> String {
        if v < 10 {
            let r = (v * 10).rounded() / 10
            return r == r.rounded() ? "\(Int(r))" : String(format: "%.1f", r)
        }
        return "\(Int(v.rounded()))"
    }

    var body: some View {
        let top = Self.niceMax(values.max() ?? 0)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Text("\(top) 分鐘").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            GeometryReader { geo in
                let usable = max(10, geo.size.height - 22)
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        HLine()
                            .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .frame(height: 1)
                        Spacer()
                        Rectangle().fill(Palette.line).frame(height: 1.5)
                    }
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(values.indices, id: \.self) { i in
                            let v = values[i]
                            VStack(spacing: 4) {
                                if v > 0 {
                                    Text(label(v)).font(.num(11, .bold)).foregroundStyle(Palette.fg)
                                }
                                Capsule()
                                    .fill(v > 0 ? (i == values.count - 1 ? Palette.orange : Palette.blue) : Palette.line)
                                    .frame(width: 22, height: v > 0 ? max(6, CGFloat(v / Double(top)) * usable) : 3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(height: 130)
            HStack(spacing: 0) {
                ForEach(labels.indices, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("近 7 天運動分鐘：" + zip(labels, values).map { "\($0) \(label($1)) 分鐘" }.joined(separator: "，"))
    }
}
