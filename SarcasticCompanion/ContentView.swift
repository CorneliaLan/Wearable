import SwiftUI

struct ContentView: View {
    @StateObject private var health = HealthManager()

    var body: some View {
        NavigationStack {
            List {
                Section("Gerät") {
                    LabeledContent("HealthKit verfügbar",
                                   value: health.isAvailable ? "Ja ✅" : "Nein ❌")
                    LabeledContent("Schreiben (Wasser)", value: health.writeStatusText)
                }

                Section {
                    Button("1. Berechtigung anfragen") {
                        Task { await health.requestAuthorization() }
                    }
                    Button("2. Alle Daten auslesen") {
                        Task { await health.testAll() }
                    }
                    Button("Testwert schreiben (250 ml Wasser)") {
                        Task { await health.writeTestWater() }
                    }
                } footer: {
                    if let message = health.message {
                        Text(message)
                    }
                }
                .disabled(!health.isAvailable)

                Section {
                    ForEach(health.items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            StatusView(status: health.statuses[item.id] ?? .notTested)
                        }
                    }
                } header: {
                    Text("Datentypen")
                } footer: {
                    Text("„Keine Daten“ kann heißen: es gibt keine Daten ODER das Lesen wurde abgelehnt – Apple unterscheidet das aus Datenschutzgründen nicht. Berechtigungen prüfen unter Einstellungen › Health › Datenzugriff & Geräte.")
                }
            }
            .navigationTitle("Sarcastic Companion")
        }
    }
}

#Preview {
    ContentView()
}
