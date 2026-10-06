# Fluxinator - Projektstatus & Kontext

## Hårdvara & Pins (ESP32-C3)
- GPIO 0: Encoder CLK (INPUT_PULLUP)
- GPIO 1: Encoder DT (INPUT_PULLUP)
- GPIO 3: Encoder SW knapp (kort tryck: växla fläkt/ljus, långt tryck >1s: toggla fläkt on/off)
- GPIO 4: 4-pin PWM Fläkt (Intel standard: 25 kHz, 8-bit upplösning)
- GPIO 5: WS2812B ARGB-slinga (12 LEDs, Adafruit NeoPixel, färgprofil 255, 240, 220)
- Ström: 12V in, buck-omvandlare till 5V för logik och LEDs.

## Mjukvaruarkitektur & BLE
- Protokoll: Nordic UART Service (NUS)
  - Service UUID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
  - RX UUID:      6E400002-B5A3-F393-E0A9-E50E24DCCA9E
  - TX UUID:      6E400003-B5A3-F393-E0A9-E50E24DCCA9E
- Enhetsnamn: "Fluxinator-C3"
- Kommandon:
  - F <0-100> (Sätter fläktprocent)
  - L <0-255> (Sätter ljusstyrka)
  - ON / OFF  (Slår till/från fläkt, behåller senast valda procent vid start)
  - STATUS    (Svarar med "FAN:<pct>;LIGHT:<val>")

## Applikationer (Swift / SwiftUI)
- Multiplatform: iOS, watchOS, macOS.
- BLEManager: Hanterar CoreBluetooth och synkronisering.
- WatchSyncManager: Strypning (80 ms) och tidsstämpling för att motverka fladder på klockan.
- Review Mode: Dold 5-taps gest på rubriken "FLUXINATOR" för demoläge vid granskning.
- SettingsView: Modern kortlayout med fast fönstergeometri (450x380 på macOS).

## Aktuell status (1.0, build 2)
- 50%-felet är åtgärdat i både firmware och Swift.
- Versionen är 1.0 på alla tre plattformar inför den första App Store-inlämningen.
- macOS: notariserad och häftad för direktdistribution med Developer ID. Byggs med
  `./scripts/release-macos.sh` (arkiv → export → notarisering → häftning → DMG).
- iOS/watchOS: signerad för App Store och verifierad som .ipa. Väntar på app-posten i
  App Store Connect och en API-nyckel innan uppladdning. Byggs med
  `./scripts/release-ios.sh`.
- Nästa planerade steg: Trådlös BLE OTA-uppdatering via GitHub Releases direkt inifrån appen.

## Signering & distribution
- Team ID: YB7SHN8MDM
- macOS: Developer ID Application-certifikat i nyckelringen. Notariseringen sker mot
  nyckelringsprofilen `fluxinator-notary`.
- iOS: automatisk signering med molnhanterat Apple Distribution-certifikat, som alltså
  inte ligger i nyckelringen. Därför krävs `-allowProvisioningUpdates`.
- Bundle-ID:n registrerade hos Apple: `com.stefanolofsson.Fluxinator` och
  `com.stefanolofsson.Fluxinator.watchkitapp`.
- App Store Connect-nyckelns Key ID och Issuer ID hör i `scripts/.asc-credentials`
  (gitignorerad). `.p8`-filen ligger i `~/.appstoreconnect/private_keys/`.
