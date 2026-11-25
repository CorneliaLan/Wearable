import Foundation
import HealthKit

/// Startet eine Workout-Session auf der Watch, damit der Puls live (ca. jede Sekunde) gemessen wird.
/// Ohne Workout misst die Watch den Puls nur gelegentlich im Hintergrund.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    private let store: HKHealthStore
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var isRunning = false
    @Published var heartRate: Double?
    @Published var lastUpdate: Date?
    @Published var sampleCount = 0
    @Published var message: String?

    init(store: HKHealthStore) {
        self.store = store
    }

    func start() async {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            builder.delegate = self
            self.session = session
            self.builder = builder

            heartRate = nil
            sampleCount = 0
            session.startActivity(with: .now)
            try await builder.beginCollection(at: .now)
            isRunning = true
            message = "Messung läuft …"
        } catch {
            message = "Start fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func stop() async {
        guard let session, let builder else { return }
        session.end()
        do {
            try await builder.endCollection(at: .now)
            // Test-Workout nicht in Health speichern.
            builder.discardWorkout()
            message = "Gestoppt – \(sampleCount) Pulswerte empfangen."
        } catch {
            message = "Stopp fehlgeschlagen: \(error.localizedDescription)"
        }
        self.session = nil
        self.builder = nil
        isRunning = false
    }

    fileprivate func update(from statistics: HKStatistics?) {
        guard let quantity = statistics?.mostRecentQuantity() else { return }
        heartRate = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        lastUpdate = .now
        sampleCount += 1
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRateType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRateType) else { return }
        let statistics = workoutBuilder.statistics(for: heartRateType)
        Task { @MainActor in
            self.update(from: statistics)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
