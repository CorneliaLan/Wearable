import Foundation
import HealthKit

/// Ein Datentyp, der getestet wird.
struct TestItem: Identifiable {
    enum Kind {
        /// Summe heute (z. B. Schritte)
        case cumulative(HKQuantityTypeIdentifier, HKUnit)
        /// Letzter Messwert (z. B. Herzfrequenz)
        case latest(HKQuantityTypeIdentifier, HKUnit)
        /// Schlaf: Anzahl Einträge der letzten 7 Tage
        case sleep
    }

    let id = UUID()
    let name: String
    let unitLabel: String
    let kind: Kind

    var objectType: HKObjectType {
        switch kind {
        case .cumulative(let id, _), .latest(let id, _):
            return HKQuantityType(id)
        case .sleep:
            return HKCategoryType(.sleepAnalysis)
        }
    }
}

enum TestStatus {
    case notTested
    case loading
    case value(String)
    case noData
    case error(String)
}

@MainActor
final class HealthManager: ObservableObject {
    let store = HKHealthStore()

    let items: [TestItem] = [
        .init(name: "Schritte (heute)", unitLabel: "Schritte", kind: .cumulative(.stepCount, .count())),
        .init(name: "Gehstrecke (heute)", unitLabel: "km", kind: .cumulative(.distanceWalkingRunning, .meterUnit(with: .kilo))),
        .init(name: "Aktive Energie (heute)", unitLabel: "kcal", kind: .cumulative(.activeEnergyBurned, .kilocalorie())),
        .init(name: "Stockwerke (heute)", unitLabel: "Stockwerke", kind: .cumulative(.flightsClimbed, .count())),
        .init(name: "Wasser (heute)", unitLabel: "ml", kind: .cumulative(.dietaryWater, .literUnit(with: .milli))),
        .init(name: "Herzfrequenz (letzte)", unitLabel: "bpm", kind: .latest(.heartRate, HKUnit.count().unitDivided(by: .minute()))),
        .init(name: "Ruhepuls (letzter)", unitLabel: "bpm", kind: .latest(.restingHeartRate, HKUnit.count().unitDivided(by: .minute()))),
        .init(name: "HRV (letzte)", unitLabel: "ms", kind: .latest(.heartRateVariabilitySDNN, .secondUnit(with: .milli))),
        .init(name: "Gewicht (letztes)", unitLabel: "kg", kind: .latest(.bodyMass, .gramUnit(with: .kilo))),
        .init(name: "Größe (letzte)", unitLabel: "cm", kind: .latest(.height, .meterUnit(with: .centi))),
        .init(name: "Schlaf (7 Tage)", unitLabel: "Einträge", kind: .sleep),
    ]

    @Published var statuses: [UUID: TestStatus] = [:]
    @Published var authRequested = false
    @Published var message: String?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var waterType: HKQuantityType { HKQuantityType(.dietaryWater) }

    /// Schreibstatus ist abfragbar – Lesestatus verrät Apple aus Datenschutzgründen nicht.
    var writeStatusText: String {
        switch store.authorizationStatus(for: waterType) {
        case .sharingAuthorized: return "erlaubt ✅"
        case .sharingDenied: return "abgelehnt ❌"
        case .notDetermined: return "noch nicht gefragt"
        @unknown default: return "unbekannt"
        }
    }

    func requestAuthorization() async {
        guard isAvailable else { return }
        let readTypes = Set(items.map(\.objectType))
        do {
            // Workout-Schreibrecht wird für die Live-Messung auf der Watch gebraucht.
            try await store.requestAuthorization(toShare: [waterType, HKObjectType.workoutType()],
                                                 read: readTypes)
            authRequested = true
            message = "Berechtigungsdialog abgeschlossen."
        } catch {
            message = "Fehler bei Berechtigung: \(error.localizedDescription)"
        }
    }

    func testAll() async {
        for item in items {
            statuses[item.id] = .loading
        }
        for item in items {
            statuses[item.id] = await test(item)
        }
    }

    private func test(_ item: TestItem) async -> TestStatus {
        do {
            switch item.kind {
            case .cumulative(let id, let unit):
                let start = Calendar.current.startOfDay(for: .now)
                let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
                let descriptor = HKStatisticsQueryDescriptor(
                    predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate),
                    options: .cumulativeSum)
                guard let sum = try await descriptor.result(for: store)?.sumQuantity() else { return .noData }
                return .value(format(sum.doubleValue(for: unit), item.unitLabel))

            case .latest(let id, let unit):
                let descriptor = HKSampleQueryDescriptor(
                    predicates: [.quantitySample(type: HKQuantityType(id))],
                    sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                    limit: 1)
                guard let sample = try await descriptor.result(for: store).first else { return .noData }
                let date = sample.endDate.formatted(date: .abbreviated, time: .shortened)
                let source = sample.sourceRevision.source.name   // z. B. „Apple Watch“ oder „iPhone“
                return .value("\(format(sample.quantity.doubleValue(for: unit), item.unitLabel)) · \(date) · \(source)")

            case .sleep:
                let start = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
                let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
                let descriptor = HKSampleQueryDescriptor(
                    predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
                    sortDescriptors: [],
                    limit: HKObjectQueryNoLimit)
                let samples = try await descriptor.result(for: store)
                return samples.isEmpty ? .noData : .value("\(samples.count) \(item.unitLabel)")
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    /// Schreibt 250 ml Wasser und testet so die Schreibberechtigung.
    func writeTestWater() async {
        let sample = HKQuantitySample(
            type: waterType,
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: 250),
            start: .now, end: .now)
        do {
            try await store.save(sample)
            message = "250 ml Wasser gespeichert ✅ – jetzt erneut testen."
        } catch {
            message = "Schreiben fehlgeschlagen ❌: \(error.localizedDescription)"
        }
        objectWillChange.send()
    }

    private func format(_ value: Double, _ unit: String) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + " " + unit
    }
}
