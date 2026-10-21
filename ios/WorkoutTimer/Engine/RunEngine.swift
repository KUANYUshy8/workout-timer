import SwiftUI
import UIKit

enum StopAction { case save, discard }

/// Runs one workout: works from wall-clock time, so it stays accurate after the app was in the background.
final class RunEngine: ObservableObject {
    struct Summary: Equatable {
        let title: String
        let active: Int
        let detail: String
        let completed: Bool
    }

    @Published private(set) var isActive = false
    @Published private(set) var phases: [Phase] = []
    @Published private(set) var index = 0
    @Published private(set) var paused = false
    @Published private(set) var now = Date()
    @Published private(set) var summary: Summary?

    weak var store: AppStore?

    private(set) var config = WorkoutConfig.standard
    private var settings = AppSettings()
    private var suffix: [Int] = [0]
    private var phaseStart = Date()
    private var pausedAt = Date()
    private var doneSec: Double = 0
    private var startedAt = Date()
    private var lastBeep: Int?
    private var announcedIndex = -1
    private var lastWorkIndex = -1
    private var timer: Timer?
    private var audioToken = 0
    private let cues = CuePlayer()

    init() {
        cues.onInterruption = { [weak self] in self?.pause() }
    }

    // MARK: Derived state

    var phase: Phase {
        phases.isEmpty ? Phase(kind: .work, duration: 1, round: 1, exercise: 1) : phases[min(index, phases.count - 1)]
    }

    var nextPhase: Phase? { index + 1 < phases.count ? phases[index + 1] : nil }

    var elapsed: Double {
        let ref = paused ? pausedAt : now
        return min(Double(phase.duration), max(0, ref.timeIntervalSince(phaseStart)))
    }

    var fraction: Double { elapsed / Double(max(1, phase.duration)) }
    var remaining: Double { Double(phase.duration) - elapsed }
    var remainingWhole: Int { Int(ceil(remaining - 1e-9)) }
    var totalSeconds: Int { suffix.first ?? 0 }

    var totalRemaining: Double {
        guard !phases.isEmpty, index + 1 < suffix.count else { return 0 }
        return Double(suffix[index + 1]) + remaining
    }

    var totalRemainingWhole: Int { Int(ceil(totalRemaining - 1e-9)) }

    var percentDone: Int {
        let t = Double(totalSeconds)
        guard t > 0 else { return 0 }
        return max(0, Int(floor((1 - totalRemaining / t) * 100)))
    }

    var workPercent: Int {
        var done = 0
        for k in 0..<min(index, phases.count) where phases[k].kind == .work { done += 1 }
        return Int((Double(done) / Double(max(1, config.moves)) * 100).rounded())
    }

    var activeSeconds: Int {
        guard !phases.isEmpty else { return 0 }
        return Int((doneSec + (phase.kind == .prep ? 0 : elapsed)).rounded())
    }

    var metaLine: String {
        let ph = phase, c = config
        switch ph.kind {
        case .prep: return "\(c.rounds) 回合，\(c.moves) 個動作，共 \(Fmt.clock(c.totalSeconds))"
        case .work: return "第 \(ph.exercise)/\(c.exercises) 個動作，第 \(ph.round)/\(c.rounds) 回合"
        case .rest: return "完成第 \(ph.exercise)/\(c.exercises) 個，第 \(ph.round)/\(c.rounds) 回合"
        case .reset: return "第 \(ph.round)/\(c.rounds) 回合完成"
        }
    }

    /// 0 = not reached, 1 = done, 2 = current. Empty when there are too many exercises to show.
    var pipStates: [Int] {
        guard config.exercises <= 24, !phases.isEmpty else { return [] }
        let ph = phase
        return (1...config.exercises).map { e -> Int in
            switch ph.kind {
            case .prep: return 0
            case .reset: return 1
            case .work: return e < ph.exercise ? 1 : (e == ph.exercise ? 2 : 0)
            case .rest: return e <= ph.exercise ? 1 : 0
            }
        }
    }

    // MARK: Control

    func start(config: WorkoutConfig, settings: AppSettings) {
        self.config = config.sanitized
        self.settings = settings
        phases = buildPhases(self.config, prep: settings.prep)
        var sums = Array(repeating: 0, count: phases.count + 1)
        for k in stride(from: phases.count - 1, through: 0, by: -1) {
            sums[k] = sums[k + 1] + phases[k].duration
        }
        suffix = sums
        lastWorkIndex = phases.lastIndex { $0.kind == .work } ?? -1
        index = 0
        paused = false
        doneSec = 0
        summary = nil
        announcedIndex = -1
        lastBeep = nil
        startedAt = Date()
        phaseStart = startedAt
        now = startedAt
        audioToken += 1
        isActive = true

        cues.start()
        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake
        if settings.notifications { PhaseNotifier.requestAuthorization() }
        announce(0, silent: false)
        scheduleNotifications()
        startTimer()
    }

    func again() {
        start(config: config, settings: store?.settings ?? settings)
    }

    func togglePause() {
        paused ? resume() : pause()
    }

    func pause() {
        guard isActive, !paused, summary == nil else { return }
        now = Date()
        pausedAt = now
        paused = true
        cues.stopSpeaking()
        PhaseNotifier.clearPending()
    }

    func resume() {
        guard isActive, paused, summary == nil else { return }
        let t = Date()
        phaseStart = phaseStart.addingTimeInterval(t.timeIntervalSince(pausedAt))
        now = t
        paused = false
        cues.start()
        scheduleNotifications()
    }

    func skip() { jump(to: index + 1) }

    func back() { jump(to: elapsed > 2 ? index : index - 1) }

    func finish(completed: Bool) {
        guard isActive, summary == nil, !phases.isEmpty else { return }
        let tail = (!completed && phase.kind != .prep) ? elapsed : 0
        let active = Int((doneSec + tail).rounded())
        var workDone = 0
        var roundsDone = 0
        let upto = completed ? phases.count : min(index, phases.count)
        for k in 0..<upto where phases[k].kind == .work {
            workDone += 1
            if phases[k].exercise == config.exercises { roundsDone += 1 }
        }
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        PhaseNotifier.clearAll()

        let record = WorkoutRecord(id: UUID().uuidString,
                                   startedAt: startedAt,
                                   endedAt: Date(),
                                   config: config,
                                   plannedSec: config.totalSeconds,
                                   activeSec: active,
                                   completed: completed,
                                   workDone: workDone,
                                   workTotal: config.moves,
                                   roundsDone: roundsDone)
        let saved = active >= 5
        if saved { store?.add(record) }
        let title = completed ? "完成！" : (saved ? "已儲存這次鍛鍊" : "已結束")
        summary = Summary(title: title,
                          active: active,
                          detail: "完成 \(roundsDone)/\(config.rounds) 回合，\(workDone)/\(config.moves) 個動作",
                          completed: completed)

        if completed {
            if settings.beep { cues.play(.finish) }
            if settings.voice { cues.speak("完成，做得好") }
            if settings.haptics { Haptics.success() }
            audioToken += 1
            let token = audioToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, self.audioToken == token else { return }
                self.cues.stop()
            }
        } else {
            cues.stop()
        }
    }

    func close() {
        stopTimer()
        audioToken += 1
        cues.stop()
        PhaseNotifier.clearAll()
        UIApplication.shared.isIdleTimerDisabled = false
        isActive = false
        paused = false
        summary = nil
    }

    func testSound(_ s: AppSettings) {
        if !isActive { cues.start() }
        if s.beep { cues.play(.work) }
        if s.voice { cues.speak("運動") }
        if s.haptics { Haptics.phase(.work) }
        guard !isActive else { return }
        audioToken += 1
        let token = audioToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, self.audioToken == token, !self.isActive else { return }
            self.cues.stop()
        }
    }

    // MARK: Internals

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isActive, !paused, summary == nil, !phases.isEmpty else { return }
        let t = Date()
        var changed = false
        while t.timeIntervalSince(phaseStart) >= Double(phases[index].duration) {
            let ph = phases[index]
            if ph.kind != .prep { doneSec += Double(ph.duration) }
            if index == phases.count - 1 {
                now = t
                finish(completed: true)
                return
            }
            phaseStart = phaseStart.addingTimeInterval(Double(ph.duration))
            index += 1
            changed = true
        }
        now = t
        if changed {
            announce(index, silent: t.timeIntervalSince(phaseStart) > 1.5)
            scheduleNotifications()
        }
        let el = t.timeIntervalSince(phaseStart)
        let left = Int(ceil(Double(phases[index].duration) - el - 1e-9))
        if settings.countdown && settings.beep && left >= 1 && left <= 3 && el >= 0.4 && left != lastBeep {
            lastBeep = left
            cues.play(.tick)
        }
    }

    private func announce(_ i: Int, silent: Bool) {
        guard announcedIndex != i, i < phases.count else { return }
        announcedIndex = i
        lastBeep = nil
        if silent { return }
        let ph = phases[i]
        if settings.beep {
            switch ph.kind {
            case .prep: cues.play(.prep)
            case .work: cues.play(.work)
            case .rest: cues.play(.rest)
            case .reset: cues.play(.reset)
            }
        }
        if settings.voice {
            cues.speak(i == lastWorkIndex ? "最後一個" : ph.kind.title)
        }
        if settings.haptics { Haptics.phase(ph.kind) }
    }

    private func jump(to target: Int) {
        guard isActive, summary == nil, !phases.isEmpty else { return }
        if phase.kind != .prep { doneSec += elapsed }
        if target >= phases.count {
            finish(completed: true)
            return
        }
        let t = Date()
        index = max(0, target)
        phaseStart = paused ? pausedAt : t
        now = t
        announcedIndex = -1
        announce(index, silent: paused)
        scheduleNotifications()
    }

    private func scheduleNotifications() {
        guard settings.notifications, isActive, !paused, summary == nil, !phases.isEmpty else {
            PhaseNotifier.clearPending()
            return
        }
        var items: [PhaseNotifier.Item] = []
        var at = phaseStart.addingTimeInterval(Double(phases[index].duration))
        var k = index + 1
        while k < phases.count && items.count < 58 {
            let p = phases[k]
            let body: String
            if k + 1 < phases.count {
                let n = phases[k + 1]
                body = "下一段：\(n.kind.title) \(Fmt.clock(n.duration))"
            } else {
                body = "最後一段，加油！"
            }
            items.append(PhaseNotifier.Item(id: "phase-\(k)",
                                            after: at.timeIntervalSinceNow,
                                            title: "\(p.kind.title) \(Fmt.clock(p.duration))",
                                            body: body))
            at = at.addingTimeInterval(Double(p.duration))
            k += 1
        }
        if k >= phases.count {
            items.append(PhaseNotifier.Item(id: "phase-done",
                                            after: at.timeIntervalSinceNow,
                                            title: "完成！",
                                            body: "總共 \(Fmt.clock(config.totalSeconds))，做得好"))
        }
        PhaseNotifier.schedule(items)
        PhaseNotifier.removeDelivered(before: index)
    }
}
