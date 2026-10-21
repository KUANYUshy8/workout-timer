import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: ConfigField?
    @State private var showPrevious = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: "運動計時器", subtitle: Fmt.todayLine())

                SectionHeader(title: "快速套用") {
                    Button {
                        showPrevious = true
                    } label: {
                        HStack(spacing: 2) {
                            Text("前次鍛鍊")
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                    }
                }
                presetChips

                SectionHeader("本次訓練")
                overview

                SectionHeader("訓練設定")
                cards
            }
            .pageContent()
        }
        .scrollIndicators(.hidden)
        .background(PageBackground())
        .sheet(item: $editing) { field in
            ConfigPickerSheet(field: field).environmentObject(store)
        }
        .sheet(isPresented: $showPrevious) {
            PreviousSheet().environmentObject(store)
        }
    }

    private var selectedPresetID: String? {
        Preset.all.first { ($0.config ?? store.custom) == store.config }?.id
    }

    private var presetChips: some View {
        let selected = selectedPresetID
        return ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Preset.all) { p in
                    ChipButton(title: p.name, tint: p.tint.color, selected: p.id == selected) {
                        store.apply(p.config ?? store.custom, remember: false)
                        if p.config == nil {
                            store.flash("已換回我的設定")
                        } else {
                            store.flash("已套用 \(p.name)：\(Fmt.clock(store.config.totalSeconds))")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }

    private var overview: some View {
        let c = store.config
        return HStack(spacing: 20) {
            ZStack {
                SegmentRing(segments: [
                    RingSegment(id: 0, value: Double(c.workTotal), color: Palette.orange),
                    RingSegment(id: 1, value: Double(c.restTotal), color: Palette.blue),
                    RingSegment(id: 2, value: Double(c.resetTotal), color: Palette.mustard),
                ])
                VStack(spacing: 6) {
                    Text(Fmt.clock(c.totalSeconds))
                        .font(.num(32, .heavy))
                        .foregroundStyle(Palette.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(c.rounds) 回合，\(c.moves) 個動作")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 22)
            }
            .frame(width: 166, height: 166)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 14) {
                LegendRow(icon: "dumbbell", color: Palette.orange, value: Fmt.clock(c.workTotal), label: "運動")
                LegendRow(icon: "pause.fill", color: Palette.blue, value: Fmt.clock(c.restTotal), label: "動作間休息")
                LegendRow(icon: "hourglass", color: Palette.mustard, value: Fmt.clock(c.resetTotal), label: "回合間休息")
            }
            Spacer(minLength: 0)
        }
    }

    private var cards: some View {
        let c = store.config
        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                SettingCard(field: .work, value: c.work, style: .work, icon: "dumbbell") { editing = .work }
                SettingCard(field: .rest, value: c.rest, style: .rest, icon: "moon") { editing = .rest }
            }
            HStack(spacing: 14) {
                SettingCard(field: .exercises, value: c.exercises, style: .green, icon: "bolt") { editing = .exercises }
                SettingCard(field: .rounds, value: c.rounds, style: .green, icon: "arrow.clockwise") { editing = .rounds }
            }
            WideSettingCard(value: c.reset) { editing = .reset }
        }
    }
}

// MARK: - Setting cards

enum CardStyle {
    case work, rest, green

    var fill: Color {
        switch self {
        case .work: return Palette.orange
        case .rest: return Palette.blueSoft
        case .green: return Palette.greenSoft
        }
    }

    var stroke: Color {
        switch self {
        case .work: return Palette.orange
        case .rest: return Palette.blue
        case .green: return Palette.green
        }
    }

    var ink: Color {
        switch self {
        case .work: return Color.white
        case .rest: return Palette.blueInk
        case .green: return Palette.greenInk
        }
    }

    var label: Color {
        self == .work ? Color.white.opacity(0.85) : Palette.muted
    }

    var archStroke: Color { self == .work ? Palette.bg : stroke }
    var archIcon: Color { self == .work ? Palette.orange : ink }
}

struct SettingCard: View {
    let field: ConfigField
    let value: Int
    let style: CardStyle
    let icon: String
    let action: () -> Void

    var body: some View {
        let parts = Fmt.valueParts(field, value)
        Button(action: action) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(parts.0).font(.num(26, .heavy))
                        Text(parts.1).font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(style.ink)
                    Text(field.cardLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(style.label)
                    Spacer(minLength: 0)
                }
                .padding(.top, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ArchShape()
                    .fill(Palette.bg)
                    .overlay(ArchShape().stroke(style.archStroke, lineWidth: 1.5))
                    .frame(width: 104, height: 54)
                    .overlay(alignment: .top) {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(style.archIcon)
                            .padding(.top, 13)
                    }
            }
            .frame(height: 156)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(style.fill)
                    RoundedRectangle(cornerRadius: 20).strokeBorder(style.stroke, lineWidth: 1.5)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(field.title) \(parts.0) \(parts.1)")
    }
}

struct WideSettingCard: View {
    let value: Int
    let action: () -> Void

    var body: some View {
        let parts = Fmt.valueParts(.reset, value)
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Palette.mustardInk)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Palette.bg))
                    .overlay(Circle().strokeBorder(Palette.mustard, lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text("回合間休息").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.fg)
                    Text("每回合做完後休息").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(parts.0).font(.num(26, .heavy))
                    Text(parts.1).font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Palette.mustardInk)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 20).fill(Palette.mustardSoft))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.mustard, lineWidth: 1.5))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("回合間休息 \(parts.0) \(parts.1)")
    }
}

// MARK: - Picker sheet

struct ConfigPickerSheet: View {
    let field: ConfigField
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var count = 1

    var body: some View {
        VStack(spacing: 0) {
            Text(field.title)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.fg)
                .padding(.top, 26)
            Text(field.hint)
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            wheels
                .frame(height: 190)
                .padding(.top, 6)
            quickChips
                .padding(.top, 4)
            HStack(spacing: 10) {
                Button("取消") { dismiss() }.buttonStyle(PillStyle(kind: .line))
                Button("完成") { save() }.buttonStyle(PillStyle(kind: .ink))
            }
            .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(470)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.bg)
        .presentationCornerRadius(28)
        .onAppear(perform: load)
    }

    @ViewBuilder private var wheels: some View {
        if field.isTime {
            HStack(spacing: 0) {
                wheel(selection: $minutes, range: 0...59, unit: "分", padded: true)
                wheel(selection: $seconds, range: 0...59, unit: "秒", padded: true)
            }
        } else {
            wheel(selection: $count, range: field.minValue...field.maxValue, unit: field.unit, padded: false)
                .frame(maxWidth: 220)
        }
    }

    private func wheel(selection: Binding<Int>, range: ClosedRange<Int>, unit: String, padded: Bool) -> some View {
        HStack(spacing: 4) {
            Picker(unit, selection: selection) {
                ForEach(Array(range), id: \.self) { v in
                    Text(padded ? String(format: "%02d", v) : "\(v)")
                        .font(.num(22, .semibold))
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 90)
            .clipped()
            Text(unit)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.fg)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(field.quick, id: \.self) { v in
                    Button {
                        set(v)
                    } label: {
                        Text(field.isTime ? Fmt.chip(v) : "\(v) \(field.unit)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.fg)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }

    private func load() {
        let v = store.config[field]
        minutes = min(59, v / 60)
        seconds = v % 60
        count = v.clamped(field.minValue, field.maxValue)
    }

    private func set(_ v: Int) {
        withAnimation {
            if field.isTime {
                minutes = v / 60
                seconds = v % 60
            } else {
                count = v
            }
        }
    }

    private func save() {
        var v = field.isTime ? minutes * 60 + seconds : count
        if v < field.minValue {
            v = field.minValue
            store.flash("\(field.title)至少要 \(field.minValue) 秒")
        }
        store.update(field, to: v)
        dismiss()
    }
}

// MARK: - Previous workouts sheet

struct PreviousSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var picks: [WorkoutRecord] {
        var seen = Set<String>()
        var out: [WorkoutRecord] = []
        for r in store.history where !seen.contains(r.config.key) {
            seen.insert(r.config.key)
            out.append(r)
            if out.count >= 6 { break }
        }
        return out
    }

    var body: some View {
        let list = picks
        VStack(spacing: 0) {
            Text("載入前次鍛鍊")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.fg)
                .padding(.top, 26)
            if list.isEmpty {
                Text("完成一次鍛鍊後，就能從這裡一鍵載入當時的設定。")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                Button("知道了") { dismiss() }
                    .buttonStyle(PillStyle(kind: .line))
                    .padding(.top, 20)
            } else {
                Text("選一次鍛鍊，套用它的時間與回合")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(list) { r in
                            Button {
                                store.apply(r.config, remember: true)
                                store.flash("已載入\(Fmt.dayLabel(r.startedAt))的鍛鍊")
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(Fmt.dayLabel(r.startedAt)) \(Fmt.hm(r.startedAt))")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Palette.fg)
                                        Text(r.config.summary)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Palette.muted)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Text(Fmt.clock(r.config.totalSeconds))
                                        .font(.num(20, .heavy))
                                        .foregroundStyle(Palette.orange)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1.5))
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .presentationDetents(list.isEmpty ? [.height(250)] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.bg)
        .presentationCornerRadius(28)
    }
}
