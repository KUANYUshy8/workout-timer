import SwiftUI

struct RunView: View {
    @EnvironmentObject var engine: RunEngine
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showStop = false
    @State private var stopAction: StopAction?
    @State private var resumeOnCancel = false

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            blobs
            if let summary = engine.summary {
                FinishView(summary: summary)
            } else {
                running
            }
        }
        .sheet(isPresented: $showStop, onDismiss: handleStopDismiss) {
            StopSheet(percent: engine.workPercent, active: engine.activeSeconds) { action in
                stopAction = action
                showStop = false
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bg)
            .presentationCornerRadius(28)
        }
    }

    private var phaseColor: Color {
        if engine.summary != nil { return Palette.blobBlue }
        switch engine.phase.kind {
        case .prep: return Palette.greenSolid
        case .work: return Palette.orange
        case .rest: return Palette.blue
        case .reset: return Palette.mustard
        }
    }

    private var blobs: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    TopBlob().fill(phaseColor).frame(width: 220, height: 200)
                }
                Spacer()
            }
            VStack {
                Spacer()
                HStack {
                    BottomBlob().fill(Palette.blobMint).frame(width: 190, height: 150)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: engine.phase.kind)
        .accessibilityHidden(true)
    }

    private var pulse: Double {
        reduceMotion ? 1 : 0.65 + 0.35 * cos(engine.now.timeIntervalSinceReferenceDate * Double.pi)
    }

    private var running: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("已完成").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                    Text("\(engine.percentDone)%").font(.num(18, .bold)).foregroundStyle(Palette.fg)
                }
                Spacer()
            }
            .padding(.top, 8)

            Text(engine.phase.kind.title)
                .font(.display(40))
                .foregroundStyle(Palette.fg)
                .padding(.top, 10)
            Text(engine.metaLine)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            PipsView(states: engine.pipStates, color: phaseColor, pulse: pulse)
                .padding(.top, 14)

            Spacer(minLength: 10)
            PhaseRing(fraction: engine.fraction,
                      color: phaseColor,
                      time: Fmt.clock(engine.remainingWhole),
                      paused: engine.paused,
                      onToggle: { engine.togglePause() })
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 340, maxHeight: 340)
            Spacer(minLength: 10)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.clock(engine.totalRemainingWhole)).font(.num(24, .bold))
                Text("總剩餘").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Palette.muted)
            nextLine.padding(.top, 6)

            HStack(spacing: 18) {
                CircleIconButton(system: "backward.end.fill", label: "回到上一段") { engine.back() }
                Button("結束") { beginStop() }
                    .buttonStyle(PillStyle(kind: .ink))
                    .frame(width: 150)
                CircleIconButton(system: "forward.end.fill", label: "跳過這段") { engine.skip() }
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var nextLine: some View {
        HStack(spacing: 0) {
            if let next = engine.nextPhase {
                Text("下一段：").foregroundStyle(Palette.muted)
                Text("\(next.kind.title) \(Fmt.clock(next.duration))").foregroundStyle(Palette.fg).fontWeight(.bold)
            } else {
                Text("最後衝刺！").foregroundStyle(Palette.fg).fontWeight(.bold)
            }
        }
        .font(.system(size: 14, weight: .semibold))
    }

    private func beginStop() {
        resumeOnCancel = !engine.paused
        engine.pause()
        stopAction = nil
        showStop = true
    }

    private func handleStopDismiss() {
        if let action = stopAction {
            if action == .save {
                engine.finish(completed: false)
            } else {
                engine.close()
            }
        } else if resumeOnCancel {
            engine.resume()
        }
        stopAction = nil
    }
}

struct PipsView: View {
    let states: [Int]
    let color: Color
    let pulse: Double

    var body: some View {
        let rows: [[Int]] = stride(from: 0, to: states.count, by: 12).map { start in
            Array(states[start..<min(start + 12, states.count)])
        }
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(rows[r].indices, id: \.self) { i in
                        let s = rows[r][i]
                        Capsule()
                            .fill(s == 0 ? Palette.line : color)
                            .opacity(s == 2 ? pulse : 1)
                            .frame(width: 18, height: 6)
                    }
                }
            }
        }
        .frame(minHeight: 6)
        .accessibilityHidden(true)
    }
}

struct PhaseRing: View {
    let fraction: Double
    let color: Color
    let time: String
    let paused: Bool
    let onToggle: () -> Void

    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = min(geo.size.width, geo.size.height)
            let knob: CGFloat = size * 0.09
            let radius: CGFloat = size / 2 - knob / 2 - 3
            let theta: Double = (1 - fraction) * 2 * Double.pi
            let cx: CGFloat = geo.size.width / 2
            let cy: CGFloat = geo.size.height / 2
            ZStack {
                Circle()
                    .stroke(Palette.line, lineWidth: max(3, size * 0.018))
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.0001, 1 - fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: size * 0.058, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .fill(color)
                    .overlay(Circle().stroke(Palette.bg, lineWidth: 5))
                    .frame(width: knob, height: knob)
                    .position(x: cx + radius * CGFloat(sin(theta)), y: cy - radius * CGFloat(cos(theta)))
                VStack(spacing: size * 0.04) {
                    Text(time)
                        .font(.num(size * 0.23, .heavy))
                        .foregroundStyle(Palette.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel("剩餘 \(time)")
                    Button(action: onToggle) {
                        Image(systemName: paused ? "play.fill" : "pause.fill")
                            .font(.system(size: size * 0.075, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: size * 0.18, height: size * 0.18)
                            .background(Circle().fill(Palette.mustard))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(paused ? "繼續" : "暫停")
                }
                if paused {
                    Text("已暫停")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.muted)
                        .offset(y: size * 0.3)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct StopSheet: View {
    let percent: Int
    let active: Int
    let choose: (StopAction?) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("要結束這次鍛鍊嗎？")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.fg)
                .padding(.top, 26)
            Text("已完成 \(percent)% 的動作，運動了 \(Fmt.clock(active))")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 8)
            Button("繼續鍛鍊") { choose(nil) }.buttonStyle(PillStyle(kind: .ink))
            Button("結束並儲存") { choose(.save) }.buttonStyle(PillStyle(kind: .line))
            Button("放棄，不儲存") { choose(.discard) }.buttonStyle(PillStyle(kind: .warn))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}

struct FinishView: View {
    let summary: RunEngine.Summary
    @EnvironmentObject var engine: RunEngine

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(Color.white)
                .frame(width: 96, height: 96)
                .background(Circle().fill(Palette.mint))
            Text(summary.title)
                .font(.display(32))
                .foregroundStyle(Palette.fg)
                .padding(.top, 12)
            Text(Fmt.clock(summary.active))
                .font(.num(60, .heavy))
                .foregroundStyle(Palette.fg)
            Text(summary.detail)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.muted)
            HStack(spacing: 12) {
                Button("再來一次") { engine.again() }.buttonStyle(PillStyle(kind: .line))
                Button("回到首頁") { engine.close() }.buttonStyle(PillStyle(kind: .ink))
            }
            .frame(maxWidth: 360)
            .padding(.top, 20)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
