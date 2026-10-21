import SwiftUI

@main
struct WorkoutTimerApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var engine = RunEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
                .onAppear { engine.store = store }
        }
    }
}
