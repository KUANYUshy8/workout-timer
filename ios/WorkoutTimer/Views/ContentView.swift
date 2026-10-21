import SwiftUI

enum AppTab: Hashable { case home, history, stats, settings }

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var engine: RunEngine
    @State private var tab: AppTab = .home

    var body: some View {
        ZStack {
            switch tab {
            case .home: HomeView()
            case .history: HistoryView(goHome: { tab = .home })
            case .stats: StatsView()
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(tab: $tab) {
                engine.start(config: store.config, settings: store.settings)
            }
        }
        .overlay(alignment: .bottom) {
            ToastView(text: store.toast).padding(.bottom, 104)
        }
        .fullScreenCover(isPresented: runBinding) {
            RunView()
                .environmentObject(store)
                .environmentObject(engine)
        }
        .tint(Palette.greenInk)
    }

    private var runBinding: Binding<Bool> {
        Binding(get: { engine.isActive }, set: { shown in
            if !shown { engine.close() }
        })
    }
}

struct TabBar: View {
    @Binding var tab: AppTab
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            NotchLine()
                .stroke(Palette.line, lineWidth: 1.5)
                .frame(height: 50)
            HStack(spacing: 0) {
                item(.home, icon: "house", activeIcon: "house.fill", label: "首頁")
                item(.history, icon: "calendar", activeIcon: "calendar", label: "歷史紀錄")
                Color.clear.frame(width: 84, height: 1)
                item(.stats, icon: "rosette", activeIcon: "rosette", label: "統計數據")
                item(.settings, icon: "person", activeIcon: "person.fill", label: "設定")
            }
            .frame(height: 64)
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.white)
                    .offset(x: 2)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(Palette.mint))
                    .shadow(color: Palette.mint.opacity(0.45), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("開始鍛鍊")
            .offset(y: -24)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Palette.bg.ignoresSafeArea(edges: .bottom))
    }

    private func item(_ t: AppTab, icon: String, activeIcon: String, label: String) -> some View {
        let isOn = tab == t
        return Button {
            tab = t
        } label: {
            Image(systemName: isOn ? activeIcon : icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isOn ? Palette.greenInk : Palette.muted)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
