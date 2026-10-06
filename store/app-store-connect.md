# App Store Connect — produktsida

Fält att klistra in i App Store Connect för **Fluxinator 1.0**. Teckengränser
står i parentes. Allt här beskriver bara funktioner som faktiskt finns i koden.

---

## App Information (gäller appen, inte versionen)

| Fält | Värde |
|---|---|
| **Name** (30) | `Fluxinator` |
| **Subtitle** (30) | `Solder fume extractor control` |
| **Primary Category** | Utilities |
| **Secondary Category** | — (lämna tom) |
| **Age Rating** | 4+ — inget olämpligt innehåll, ingen webbläsare, inget användargenererat |
| **Content Rights** | Innehåller inget tredjepartsinnehåll |
| **Bundle ID** | `com.stefanolofsson.Fluxinator` |

---

## Version Information (1.0)

### Promotional Text (170)

```
Dial in your extraction from across the bench — speed, presets and stop, on your iPhone, iPad and Apple Watch.
```

### Description (4000)

```
Fluxinator turns your iPhone into the control panel for your solder fume extractor.

Set the fan anywhere from 0 to 100 percent, jump straight to a preset, or stop it with one tap — without putting down the iron or reaching behind the bench.

CONTROL
• Continuous speed control from 0 to 100 percent
• Four presets: 25%, 50%, 75% and MAX
• ENGAGE and STOP, with your last speed remembered between runs
• Connection status at a glance

ON YOUR WRIST
The Apple Watch app carries the same dial, presets and stop button, and stays in sync with your iPhone as you change the speed on either one.

BUILT FOR THE BENCH
A dark theme by default, with light and system options. On iPad the dial and the controls sit side by side. There is nothing to sign in to, no account and no analytics — the app speaks Bluetooth directly to your own hardware, and nothing leaves your device.

REQUIRES FLUXINATOR HARDWARE
This app is the remote for a Fluxinator fume extractor: an ESP32-C3, a four-pin PWM fan and a WS2812B ring. It connects over Bluetooth Low Energy using the Nordic UART Service. Without that hardware there is nothing for the app to control.
```

### Keywords (100, kommaseparerat utan blanksteg)

```
solder,fume,extractor,fan,pwm,bluetooth,ble,esp32,remote,workshop,electronics,maker,diy,bench
```

### Copyright

```
2026 Stefan Olofsson
```

### URL:er — måste fyllas i av dig

| Fält | Krav | Förslag |
|---|---|---|
| **Privacy Policy URL** | **obligatorisk** | publicera `store/privacy-policy.md` via GitHub Pages |
| **Support URL** | **obligatorisk** | `https://github.com/stefanolofsson/fluxinator/issues` |
| **Marketing URL** | valfri | `https://github.com/stefanolofsson/fluxinator` |

---

## App Review Information

Det här avsnittet är det viktigaste i hela inlämningen. Appen kan inte göra
någonting utan hårdvaran, och en granskare som inte vet om demoläget kommer att
se en app som bara står och söker — vilket är en vanlig avslagsorsak.

### Notes

```
Fluxinator is the remote control for a piece of DIY hardware — a solder fume
extractor built around an ESP32-C3 — and has nothing to connect to without it.

To review the full interface without the hardware, enable the built-in demo mode:
tap the yellow "FLUXINATOR" title on the main screen five times. The status
changes to CONNECTED and every control becomes operable against simulated
hardware. Tap the title five times again to leave demo mode.

The app uses Bluetooth only to reach that one device, over the Nordic UART
Service. There are no accounts, no network requests and no data collection.
```

### Sign-in required

Nej — appen har ingen inloggning.

---

## App Privacy

Koden importerar bara SwiftUI, Combine, Foundation, CoreBluetooth och
WatchConnectivity. Det finns inga nätverksanrop, ingen analys och ingen tracking.
Det enda som lagras är temavalet, lokalt i UserDefaults.

Svara därför **Data Not Collected** på hela frågeformuläret. Bluetooth räknas
inte som insamlad data när den bara används för att styra användarens egen enhet
och ingenting lämnar telefonen.

---

## Skärmbilder

Obligatoriskt för en iOS-app som stöder iPhone, iPad och har en Watch-app:

| Uppsättning | Krav | Upplösning | Simulator |
|---|---|---|---|
| iPhone 6,9" | **obligatorisk** | 1320 × 2868 | iPhone 18 Pro Max |
| iPad 13" | **obligatorisk** (iPad stöds) | 2064 × 2752 | iPad Pro 13-inch (M5) |
| Apple Watch | **obligatorisk** (Watch-app ingår) | 410 × 502 | Apple Watch Series 10 (46mm) |

Minst en bild per uppsättning, högst tio. De ligger i `store/screenshots/`.

---

## Att besluta innan inlämning

**`TARGETED_DEVICE_FAMILY = "1,2,7"`** inkluderar Vision Pro. Det gör att App
Store Connect kan begära en Vision Pro-uppsättning och att appen erbjuds där i
kompatibilitetsläge. Vill du bara iPhone och iPad är värdet `"1,2"`.

**Appen når inte all hårdvarufunktionalitet.** Firmware stöder `L <0-255>` för
ARGB-ljusstyrkan och svarar på `STATUS` med uppmätt varvtal, men ingen vy
exponerar ljusstyrkan och `rpm` visas aldrig — det skickas bara vidare till
klockan. Beskrivningen ovan utelämnar därför båda. Vill du ha dem i 1.0 är det
en kodändring, inte en textändring.
