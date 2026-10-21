import SwiftUI

struct AppSettings: Codable, Equatable {
    var prep: Int = 5
    var beep: Bool = true
    var countdown: Bool = true
    var voice: Bool = true
    var haptics: Bool = true
    var notifications: Bool = true
    var keepAwake: Bool = true
    var weeklyGoal: Int = 60

    init() {}

    // Tolerates settings saved by older versions that lack newer keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        prep = try c.decodeIfPresent(Int.self, forKey: .prep) ?? d.prep
        beep = try c.decodeIfPresent(Bool.self, forKey: .beep) ?? d.beep
        countdown = try c.decodeIfPresent(Bool.self, forKey: .countdown) ?? d.countdown
        voice = try c.decodeIfPresent(Bool.self, forKey: .voice) ?? d.voice
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        notifications = try c.decodeIfPresent(Bool.self, forKey: .notifications) ?? d.notifications
        keepAwake = try c.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? d.keepAwake
        weeklyGoal = try c.decodeIfPresent(Int.self, forKey: .weeklyGoal) ?? d.weeklyGoal
    }
}

/// Holds the current timer settings, app preferences and workout history, saved on the device.
final class AppStore: ObservableObject {
    @Published var config: WorkoutConfig { didSet { Self.save(config, key: "config") } }
    @Published var custom: WorkoutConfig { didSet { Self.save(custom, key: "custom") } }
    @Published var settings: AppSettings { didSet { Self.save(settings, key: "settings") } }
    @Published private(set) var history: [WorkoutRecord] = []
    @Published private(set) var toast: String?

    private var toastWork: DispatchWorkItem?

    init() {
        config = (Self.load(WorkoutConfig.self, key: "config") ?? .standard).sanitized
        custom = (Self.load(WorkoutConfig.self, key: "custom") ?? .standard).sanitized
        settings = Self.load(AppSettings.self, key: "settings") ?? AppSettings()
        history = Self.loadHistory()
    }

    // MARK: Config

    func apply(_ c: WorkoutConfig, remember: Bool) {
        config = c.sanitized
        if remember { custom = config }
    }

    func update(_ field: ConfigField, to value: Int) {
        var c = config
        c[field] = value
        config = c.sanitized
        custom = config
    }

    // MARK: History

    var hasHistory: Bool { !history.isEmpty }
    var displayHistory: [WorkoutRecord] { history.isEmpty ? Self.samples() : history }

    func add(_ record: WorkoutRecord) {
        history.insert(record, at: 0)
        history.sort { $0.endedAt > $1.endedAt }
        if history.count > 1000 { history.removeLast(history.count - 1000) }
        persistHistory()
    }

    func delete(_ record: WorkoutRecord) {
        history.removeAll { $0.id == record.id }
        persistHistory()
    }

    func clearHistory() {
        history = []
        persistHistory()
    }

    // MARK: Toast

    func flash(_ text: String) {
        toastWork?.cancel()
        withAnimation { toast = text }
        let work = DispatchWorkItem { [weak self] in
            withAnimation { self?.toast = nil }
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    // MARK: Persistence

    private static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: "ivt." + key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: "ivt." + key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static var historyURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("history.json")
    }

    private static func loadHistory() -> [WorkoutRecord] {
        guard let data = try? Data(contentsOf: historyURL),
              let list = try? JSONDecoder().decode([WorkoutRecord].self, from: data) else { return [] }
        return list.sorted { $0.endedAt > $1.endedAt }
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: Self.historyURL, options: .atomic)
        }
    }

    // MARK: Sample data (shown only until the first real workout)

    static func samples() -> [WorkoutRecord] {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let specs: [(Int, Double, WorkoutConfig, Double)] = [
            (0, 7.5, WorkoutConfig(work: 30, rest: 15, exercises: 8, rounds: 3, reset: 60), 1),
            (1, 18.5, WorkoutConfig(work: 8, rest: 20, exercises: 6, rounds: 6, reset: 120), 1),
            (2, 7.2, WorkoutConfig(work: 20, rest: 10, exercises: 8, rounds: 1, reset: 0), 1),
            (3, 19, WorkoutConfig(work: 40, rest: 20, exercises: 6, rounds: 3, reset: 60), 0.6),
            (5, 18, WorkoutConfig(work: 8, rest: 20, exercises: 6, rounds: 6, reset: 120), 1),
            (6, 7.5, WorkoutConfig(work: 45, rest: 15, exercises: 5, rounds: 3, reset: 90), 1),
            (8, 19.2, WorkoutConfig(work: 30, rest: 15, exercises: 8, rounds: 3, reset: 60), 1),
        ]
        var out: [WorkoutRecord] = []
        for (i, spec) in specs.enumerated() {
            let day = cal.date(byAdding: .day, value: -spec.0, to: base) ?? base
            let start = day.addingTimeInterval(spec.1 * 3600)
            let planned = spec.2.totalSeconds
            let active = Int((Double(planned) * spec.3).rounded())
            let total = spec.2.moves
            out.append(WorkoutRecord(id: "sample\(i)",
                                     startedAt: start,
                                     endedAt: start.addingTimeInterval(Double(active) + 30),
                                     config: spec.2,
                                     plannedSec: planned,
                                     activeSec: active,
                                     completed: spec.3 >= 1,
                                     workDone: Int((Double(total) * spec.3).rounded()),
                                     workTotal: total,
                                     roundsDone: Int(Double(spec.2.rounds) * spec.3),
                                     isSample: true))
        }
        return out.sorted { $0.endedAt > $1.endedAt }
    }
}
