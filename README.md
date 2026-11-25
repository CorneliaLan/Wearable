# Sarcastic Companion – HealthKit Test

Einfache SwiftUI-App für iPhone und Apple Watch, die testet, ob HealthKit-Daten ausgelesen werden können.

## iPhone
- Prüft, ob HealthKit verfügbar ist, und fragt Lese-/Schreibberechtigungen an
- Liest 11 Datentypen (Schritte, Strecke, Energie, Stockwerke, Wasser, Herzfrequenz, Ruhepuls, HRV, Gewicht, Größe, Schlaf) und zeigt Wert, Zeitpunkt und Quelle (z. B. „Apple Watch“)
- Schreibt einen Testwert (250 ml Wasser), um die Schreibberechtigung zu prüfen

## Apple Watch
- **Live-Puls** über eine Workout-Session (`HKWorkoutSession` + `HKLiveWorkoutBuilder`), ca. ein Wert pro Sekunde; das Test-Workout wird nicht gespeichert
- Dieselbe Datenliste wie am iPhone, gelesen aus der Health-Datenbank der Watch

## Aufbau
```
SarcasticCompanion/        iPhone-App
SarcasticCompanionWatch/   Watch-App (inkl. WorkoutManager)
Shared/                    HealthManager und StatusView (beide Targets)
project.yml                XcodeGen-Konfiguration
```

## Projekt erzeugen und öffnen
Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt:
```bash
xcodegen generate
open SarcasticCompanion.xcodeproj
```
Schemes: **SarcasticCompanion iPhone** und **SarcasticCompanion Watch**. Signing-Team in `project.yml` (`DEVELOPMENT_TEAM`) anpassen.

## Watch-App auf die echte Uhr bringen
Falls Xcode die Uhr nicht direkt koppeln kann:
1. Uhr im Apple Developer Account unter *Devices* mit ihrer UDID registrieren
2. iPhone-App bauen und aufs iPhone installieren (die Watch-App ist eingebettet)
3. Am iPhone in der Watch-App unter *Meine Watch › Sarcastic Companion* auf **Installieren** tippen
