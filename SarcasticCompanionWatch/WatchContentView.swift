import SwiftUI

struct WatchContentView: View {
    @StateObject private var health: HealthManager
    @StateObject private var workout: WorkoutManager

    init() {
        let health = HealthManager()
        _health = StateObject(wrappedValue: health)
        _workout = StateObject(wrappedValue: WorkoutManager(store: health.store))
    }

    var body: some View {
        TabView {
            LiveHeartRateView(health: health, workout: workout)
            WatchDataListView(health: health)
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Seite 1: Live-Puls

struct LiveHeartRateView: View {
    @ObservedObject var health: HealthManager
    @ObservedObject var workout: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Live-Puls").font(.headline)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, isActive: workout.isRunning)
                    Text(workout.heartRate.map { "\(Int($0))" } ?? "--")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("bpm").foregroundStyle(.secondary)
                }

                if let date = workout.lastUpdate {
                    Text("\(workout.sampleCount) Werte · \(date.formatted(date: .omitted, time: .standard))")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                if !health.authRequested {
                    Button("Berechtigung anfragen") {
                        Task { await health.requestAuthorization() }
                    }
                }

                Button(workout.isRunning ? "Stoppen" : "Messung starten") {
                    Task {
                        if workout.isRunning { await workout.stop() } else { await workout.start() }
                    }
                }
                .tint(workout.isRunning ? .red : .green)
                .disabled(!health.isAvailable)

                if let message = workout.message ?? health.message {
                    Text(message).font(.caption2).multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Seite 2: Gespeicherte Daten auf der Watch

struct WatchDataListView: View {
    @ObservedObject var health: HealthManager

    var body: some View {
        List {
            Section {
                Text(health.isAvailable ? "HealthKit verfügbar ✅" : "HealthKit nicht verfügbar ❌")
                    .font(.caption)
                Button("Alle Daten auslesen") {
                    Task { await health.testAll() }
                }
            }

            ForEach(health.items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.caption)
                    StatusView(status: health.statuses[item.id] ?? .notTested)
                        .font(.caption2)
                }
            }

            Text("Die Watch speichert nur Daten der letzten Tage lokal – ältere liegen nur am iPhone.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
