import Foundation

extension Int {
    func clamped(_ lower: Int, _ upper: Int) -> Int { Swift.min(upper, Swift.max(lower, self)) }
}

// MARK: - Workout configuration

struct WorkoutConfig: Codable, Equatable, Hashable {
    var work: Int = 8
    var rest: Int = 20
    var exercises: Int = 6
    var rounds: Int = 6
    var reset: Int = 120

    static let standard = WorkoutConfig()

    var sanitized: WorkoutConfig {
        WorkoutConfig(work: work.clamped(1, 3599),
                      rest: rest.clamped(0, 3599),
                      exercises: exercises.clamped(1, 50),
                      rounds: rounds.clamped(1, 50),
                      reset: reset.clamped(0, 3599))
    }

    var workTotal: Int { rounds * exercises * work }
    var restTotal: Int { rounds * (exercises - 1) * rest }
    var resetTotal: Int { (rounds - 1) * reset }
    var totalSeconds: Int { workTotal + restTotal + resetTotal }
    var moves: Int { exercises * rounds }
    var key: String { "\(work)-\(rest)-\(exercises)-\(rounds)-\(reset)" }
    var summary: String { "運動 \(Fmt.short(work))／休息 \(Fmt.short(rest))，\(exercises) 個 × \(rounds) 回合" }

    subscript(field: ConfigField) -> Int {
        get {
            switch field {
            case .work: return work
            case .rest: return rest
            case .exercises: return exercises
            case .rounds: return rounds
            case .reset: return reset
            }
        }
        set {
            switch field {
            case .work: work = newValue
            case .rest: rest = newValue
            case .exercises: exercises = newValue
            case .rounds: rounds = newValue
            case .reset: reset = newValue
            }
        }
    }
}

enum ConfigField: String, Identifiable, CaseIterable {
    case work, rest, exercises, rounds, reset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: return "運動時間"
        case .rest: return "休息時間"
        case .exercises: return "每回合動作"
        case .rounds: return "回合數"
        case .reset: return "回合間休息"
        }
    }

    var cardLabel: String {
        switch self {
        case .work: return "運動時間"
        case .rest: return "休息時間"
        case .exercises: return "每回合動作"
        case .rounds: return "重複次數"
        case .reset: return "回合間休息"
        }
    }

    var hint: String {
        switch self {
        case .work: return "每個動作要做多久"
        case .rest: return "動作之間休息多久，設為 0 就不休息"
        case .exercises: return "一個回合裡有幾個動作"
        case .rounds: return "整組動作要重複幾次"
        case .reset: return "每回合做完後的休息，設為 0 就直接進下一回合"
        }
    }

    var isTime: Bool { self == .work || self == .rest || self == .reset }
    var minValue: Int { self == .rest || self == .reset ? 0 : 1 }
    var maxValue: Int { isTime ? 3599 : 50 }
    var unit: String { self == .exercises ? "個" : "回合" }

    var quick: [Int] {
        switch self {
        case .work: return [20, 30, 40, 45, 60]
        case .rest: return [0, 10, 15, 20, 30]
        case .exercises: return [4, 6, 8, 10]
        case .rounds: return [1, 3, 4, 6, 8]
        case .reset: return [0, 30, 60, 90, 120]
        }
    }
}

// MARK: - Presets

enum PresetTint { case green, mustard, blue }

struct Preset: Identifiable {
    let id: String
    let name: String
    let tint: PresetTint
    /// nil means "the user's own settings".
    let config: WorkoutConfig?

    static let all: [Preset] = [
        Preset(id: "custom", name: "我的設定", tint: .green, config: nil),
        Preset(id: "tabata", name: "Tabata", tint: .green, config: WorkoutConfig(work: 20, rest: 10, exercises: 8, rounds: 1, reset: 0)),
        Preset(id: "hiit", name: "HIIT", tint: .mustard, config: WorkoutConfig(work: 40, rest: 20, exercises: 6, rounds: 3, reset: 60)),
        Preset(id: "burn", name: "燃脂循環", tint: .blue, config: WorkoutConfig(work: 30, rest: 15, exercises: 8, rounds: 3, reset: 60)),
        Preset(id: "core", name: "核心訓練", tint: .green, config: WorkoutConfig(work: 45, rest: 15, exercises: 5, rounds: 3, reset: 90)),
    ]
}

// MARK: - Phases

enum PhaseKind: String {
    case prep, work, rest, reset

    var title: String {
        switch self {
        case .prep: return "準備"
        case .work: return "運動"
        case .rest: return "休息"
        case .reset: return "回合休息"
        }
    }
}

struct Phase: Equatable {
    let kind: PhaseKind
    let duration: Int
    let round: Int
    let exercise: Int
}

func buildPhases(_ c: WorkoutConfig, prep: Int) -> [Phase] {
    var list: [Phase] = []
    if prep > 0 { list.append(Phase(kind: .prep, duration: prep, round: 1, exercise: 0)) }
    for r in 1...max(1, c.rounds) {
        for e in 1...max(1, c.exercises) {
            list.append(Phase(kind: .work, duration: c.work, round: r, exercise: e))
            if e < c.exercises && c.rest > 0 {
                list.append(Phase(kind: .rest, duration: c.rest, round: r, exercise: e))
            }
        }
        if r < c.rounds && c.reset > 0 {
            list.append(Phase(kind: .reset, duration: c.reset, round: r, exercise: c.exercises))
        }
    }
    return list
}

// MARK: - History

struct WorkoutRecord: Codable, Identifiable, Equatable {
    var id: String
    var startedAt: Date
    var endedAt: Date
    var config: WorkoutConfig
    var plannedSec: Int
    var activeSec: Int
    var completed: Bool
    var workDone: Int
    var workTotal: Int
    var roundsDone: Int
    var isSample: Bool = false

    var percent: Int { Int((Double(workDone) / Double(max(1, workTotal)) * 100).rounded()) }
}

// MARK: - Formatting

enum Fmt {
    static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = s % 3600 / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%02d:%02d", m, x)
    }

    static func short(_ s: Int) -> String {
        if s == 0 { return "0 秒" }
        if s < 60 { return "\(s) 秒" }
        let m = s / 60, x = s % 60
        return x > 0 ? "\(m) 分 \(x) 秒" : "\(m) 分鐘"
    }

    static func chip(_ s: Int) -> String {
        if s == 0 { return "不休息" }
        if s < 60 { return "\(s) 秒" }
        let m = s / 60, x = s % 60
        return x > 0 ? "\(m):" + String(format: "%02d", x) : "\(m) 分鐘"
    }

    static func valueParts(_ field: ConfigField, _ v: Int) -> (String, String) {
        switch field {
        case .exercises: return ("\(v)", "個")
        case .rounds: return ("\(v)", "回合")
        default:
            if v < 60 { return ("\(v)", "秒") }
            if v % 60 == 0 { return ("\(v / 60)", "分鐘") }
            return ("\(v / 60):" + String(format: "%02d", v % 60), "分")
        }
    }

    static func weekday(_ d: Date) -> String {
        weekdays[Calendar.current.component(.weekday, from: d) - 1]
    }

    static func dayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
        if diff == 0 { return "今天" }
        if diff == 1 { return "昨天" }
        let c = cal.dateComponents([.month, .day], from: d)
        return "\(c.month ?? 0)月\(c.day ?? 0)日 週\(weekday(d))"
    }

    static func hm(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func todayLine() -> String {
        let d = Date()
        let c = Calendar.current.dateComponents([.month, .day], from: d)
        return "\(c.month ?? 0)月\(c.day ?? 0)日，星期\(weekday(d))"
    }
}
