import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var engine: RunEngine
    @State private var clearArmed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: "設定", subtitle: "提示音、準備倒數與目標")

                GroupTitle("計時")
                SettingsGroup {
                    OptionRow(title: "準備倒數",
                              detail: "按下開始後先倒數，讓你就定位",
                              options: [Option(0, "無"), Option(5, "5 秒"), Option(10, "10 秒"), Option(15, "15 秒")],
                              selection: $store.settings.prep)
                    RowDivider()
                    OptionRow(title: "每週目標",
                              detail: "統計頁的大圓環以這個分鐘數計算",
                              options: [Option(30, "30"), Option(60, "60"), Option(90, "90"), Option(150, "150 分")],
                              selection: $store.settings.weeklyGoal)
                }

                GroupTitle("提示")
                SettingsGroup {
                    ToggleRow(title: "提示音", detail: "每個階段開始時響一聲", isOn: $store.settings.beep)
                    RowDivider()
                    ToggleRow(title: "最後 3 秒倒數", detail: "階段結束前每秒嗶一聲", isOn: $store.settings.countdown)
                    RowDivider()
                    ToggleRow(title: "語音播報", detail: "唸出「運動」「休息」等階段名稱", isOn: $store.settings.voice)
                    RowDivider()
                    ToggleRow(title: "震動", detail: "換階段時手機震一下（App 在前景時）", isOn: $store.settings.haptics)
                    RowDivider()
                    ToggleRow(title: "鎖定畫面通知", detail: "鎖螢幕或切到其他 App 時，顯示現在是哪個階段", isOn: $store.settings.notifications)
                    RowDivider()
                    ActionRow(title: "試聽提示音", detail: "確認手機沒有靜音、音量夠大", icon: "speaker.wave.2") {
                        engine.testSound(store.settings)
                    }
                }

                GroupTitle("螢幕")
                SettingsGroup {
                    ToggleRow(title: "鍛鍊時保持螢幕開啟", detail: "避免手機自動鎖定而看不到倒數", isOn: $store.settings.keepAwake)
                }

                GroupTitle("資料")
                SettingsGroup {
                    ActionRow(title: "恢復預設計時", detail: "運動 8 秒、休息 20 秒、6 個動作 × 6 回合、回合間 2 分鐘") {
                        store.apply(.standard, remember: true)
                        store.flash("已恢復預設計時")
                    }
                    RowDivider()
                    ActionRow(title: clearArmed ? "再按一次確認清除" : "清除所有紀錄", detail: "刪除後無法復原", danger: true) {
                        clearHistory()
                    }
                }

                Text("運動計時器 1.0　紀錄只存在這支手機")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            }
            .pageContent()
        }
        .scrollIndicators(.hidden)
        .background(PageBackground())
        .onChange(of: store.settings.notifications) { _, on in
            if on { PhaseNotifier.requestAuthorization() }
        }
    }

    private func clearHistory() {
        guard store.hasHistory else {
            store.flash("目前沒有紀錄")
            return
        }
        if clearArmed {
            clearArmed = false
            store.clearHistory()
            store.flash("已清除所有紀錄")
        } else {
            clearArmed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { clearArmed = false }
        }
    }
}

struct Option: Identifiable {
    let value: Int
    let label: String
    var id: Int { value }

    init(_ value: Int, _ label: String) {
        self.value = value
        self.label = label
    }
}

struct GroupTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.muted)
            .padding(.top, 26)
            .padding(.leading, 4)
    }
}

struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.top, 10)
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Palette.line).frame(height: 1.5)
    }
}

struct RowText: View {
    let title: String
    let detail: String
    var danger = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(danger ? Palette.orange : Palette.fg)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            RowText(title: title, detail: detail)
        }
        .tint(Palette.greenSolid)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct OptionRow: View {
    let title: String
    let detail: String
    let options: [Option]
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RowText(title: title, detail: detail)
            HStack(spacing: 6) {
                ForEach(options) { o in
                    let on = selection == o.value
                    Button {
                        selection = o.value
                    } label: {
                        Text(o.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(on ? Palette.bg : Palette.muted)
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(Capsule().fill(on ? Palette.fg : Color.clear))
                            .overlay(Capsule().strokeBorder(on ? Palette.fg : Palette.line, lineWidth: 1.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActionRow: View {
    let title: String
    let detail: String
    var icon: String? = nil
    var danger = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RowText(title: title, detail: detail, danger: danger)
                Spacer(minLength: 0)
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Palette.fg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
