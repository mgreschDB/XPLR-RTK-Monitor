# XPLR RTK Monitor

iOS App zur Live-Überwachung des XPLR-HPG2 RTK-Logger Boards via Bluetooth Low Energy.

## Features
- **Live-Karte** mit aktueller Position (MapKit)
- **Fix-Status** farbcodiert: RTK-Fixed (grün), RTK-Float (orange), 3D (blau), DR (lila)
- **Statistiken:** Satelliten, Accuracy, Speed
- **Remote Shutdown** — Board sauber per Button herunterfahren
- **Auto-Connect** zum `XPLR-HPG2-RTK` Gerät

## Voraussetzungen
- iPhone mit iOS 16+
- Xcode 15+ (zum Bauen)
- XPLR-HPG2 Board mit BLE-Firmware

## Installation
1. `XPLR-RTK-Monitor.xcodeproj` in Xcode öffnen
2. Team/Signing konfigurieren (eigenes Apple Developer Account)
3. iPhone anschließen
4. Build & Run (⌘R)

## Bedienung
1. App öffnen → "Scan" tippen
2. `XPLR-HPG2-RTK` auswählen → verbindet automatisch
3. Position erscheint auf der Karte, Status wird live aktualisiert
4. "Shutdown" Button → Board fährt sauber runter

## BLE Protokoll
| Characteristic | UUID (Ende) | Funktion |
|---|---|---|
| NMEA | `...0001` | GGA Notify → Position parsen |
| Control | `...0002` | Write `0x01` = Shutdown, `0x02` = Restart |
| Status | `...0003` | Read/Notify: `FixType,Sats,HAcc_mm,Speed` |

## Projektstruktur
```
XPLR-RTK-Monitor/
├── XPLR_RTK_MonitorApp.swift   ← App Entry Point
├── ContentView.swift           ← UI (Map, Status, Buttons)
├── BLEManager.swift            ← BLE Kommunikation + NMEA Parsing
└── Info.plist                  ← Bluetooth Permissions
```
