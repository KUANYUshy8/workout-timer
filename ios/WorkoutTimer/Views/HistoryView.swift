import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    let goHome: () -> Void
    @State private var selectedDay: Date?
    @State private var detail: WorkoutRecord?

    private struct DayGroup: Identifiable {
        let day: Date
        var items: [WorkoutRecord]
        var id: Date { day }
    }

    var body: some View {
        let list = store.displayHistory
        let isSample = !store.hasHistory
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: "歷史紀錄",
                          subtitle: isSample ? "還沒有紀錄，先看看範例" : "共 \(store.history.count) 次鍛鍊")
                monthRow.padding(.top, 16)
                weekStrip(list).padding(.top, 18)
                Rectangle().fill(Palette.line).frame(height: 1.5).padding(.top, 16)
                if isSample {
                    NoteView("以下是範例資料。完成第一次鍛鍊後，這裡會換成你自己的紀錄。").padding(.top, 16)
                }
                records(list)
            }
            .pageContent()
        }
        .scrollIndicators(.hidden)
        .background(PageBackground())
        .sheet(item: $detail) { record in
            RecordSheet(record: record, goHome: goHome).environmentObject(store)
        }
    }

    private var monthRow: some View {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.greenInk)
            Text("\(String(c.year ?? 2026)) 年 \(c.month ?? 1) 月")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.fg)
        }
    }

    private func weekStrip(_ list: [WorkoutRecord]) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days: [Date] = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let has = Set(list.map { cal.startOfDay(for: $0.startedAt) })
        return HStack(spacing: 4) {
            ForEach(days, id: \.self) { d in
                DayCell(date: d, isToday: d == today, hasRecord: has.contains(d), selected: selectedDay == d) {
                    selectedDay = (selectedDay == d) ? nil : d
                }
            }
        }
    }

    @ViewBuilder
    private func records(_ list: [WorkoutRecord]) -> some View {
        let cal = Calendar.current
        let shown: [WorkoutRecord] = {
            guard let day = selectedDay else { return list }
            return list.filter { cal.isDate($0.startedAt, inSameDayAs: day) }
        }()
        if shown.isEmpty, let day = selectedDay {
            Text("\(Fmt.dayLabel(day))沒有鍛鍊紀錄。\n再點一次日期可以看全部。")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 34)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(groupByDay(shown)) { group in
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.dayLabel(group.day))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.fg)
                        Spacer()
                        Text("\(group.items.count) 次，\(minutes(group.items)) 分鐘")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(.top, 16)
                    ForEach(group.items) { record in
                        Button {
                            detail = record
                        } label: {
                            RecordRow(record: record)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
    }

    private func minutes(_ items: [WorkoutRecord]) -> Int {
        Int((Double(items.reduce(0) { $0 + $1.activeSec }) / 60).rounded())
    }

    private func groupByDay(_ list: [WorkoutRecord]) -> [DayGroup] {
        let cal = Calendar.current
        var out: [DayGroup] = []
        for r in list {
            let d = cal.startOfDay(for: r.startedAt)
            if let last = out.last, last.day == d {
                out[out.count - 1].items.append(r)
            } else {
                out.append(DayGroup(day: d, items: [r]))
            }
        }
        return out
    }
}

struct DayCell: View {
    let date: Date
    let isToday: Bool
    let hasRecord: Bool
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let day = Calendar.current.component(.day, from: date)
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.num(19, .semibold))
                    .foregroundStyle(selected ? Palette.onGreen : Palette.fg)
                Text(isToday ? "今天" : "週" + Fmt.weekday(date))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selected ? Palette.onGreen.opacity(0.75) : Palette.muted)
                Circle()
                    .fill(hasRecord ? (selected ? Palette.onGreen : Palette.orange) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Palette.green : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Fmt.dayLabel(date))\(hasRecord ? "，有紀錄" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct RecordRow: View {
    let record: WorkoutRecord

    var body: some View {
        let pct = record.percent
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(fraction: Double(pct) / 100,
                             color: record.completed ? Palette.greenSolid : Palette.mustard,
                             lineWidth: 4)
                if record.completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Palette.greenInk)
                } else {
                    Text("\(pct)%")
                        .font(.num(11, .bold))
                        .foregroundStyle(Palette.fg)
                }
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.clock(record.activeSec))
                    .font(.num(20, .bold))
                    .foregroundStyle(Palette.fg)
                Text(record.config.summary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(Fmt.hm(record.startedAt))
                .font(.num(13, .semibold))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.bg))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1.5))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct KVCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
            Text(value)
                .font(.num(18, .bold))
                .foregroundStyle(Palette.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line, lineWidth: 1.5))
    }
}

struct RecordSheet: View {
    let record: WorkoutRecord
    let goHome: () -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var armed = false

    var body: some View {
        let c = record.config.sanitized
        VStack(spacing: 0) {
            Text("\(Fmt.dayLabel(record.startedAt)) \(Fmt.hm(record.startedAt))\(record.isSample ? "（範例）" : "")")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.fg)
                .padding(.top, 26)
            Text(Fmt.clock(record.activeSec))
                .font(.num(50, .heavy))
                .foregroundStyle(Palette.fg)
                .padding(.vertical, 8)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                KVCell(label: "完成度", value: "\(record.percent)%")
                KVCell(label: "計畫時間", value: Fmt.clock(record.plannedSec))
                KVCell(label: "動作", value: "\(record.workDone)/\(record.workTotal)")
                KVCell(label: "回合", value: "\(record.roundsDone)/\(c.rounds)")
                KVCell(label: "運動／休息", value: "\(Fmt.clock(c.work))／\(Fmt.clock(c.rest))")
                KVCell(label: "回合間休息", value: Fmt.clock(c.reset))
            }
            VStack(spacing: 10) {
                Button("用這個設定") {
                    store.apply(c, remember: true)
                    store.flash("已載入這次鍛鍊的設定")
                    dismiss()
                    goHome()
                }
                .buttonStyle(PillStyle(kind: .ink))
                if !record.isSample {
                    Button(armed ? "再按一次確認刪除" : "刪除這筆紀錄") {
                        if armed {
                            store.delete(record)
                            store.flash("已刪除這筆紀錄")
                            dismiss()
                        } else {
                            armed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { armed = false }
                        }
                    }
                    .buttonStyle(PillStyle(kind: .warn))
                }
            }
            .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(record.isSample ? 480 : 544)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.bg)
        .presentationCornerRadius(28)
    }
}
