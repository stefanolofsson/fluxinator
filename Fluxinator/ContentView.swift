import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEManager.shared
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .dark
    @State private var showingSettings = false
    @Environment(\.colorScheme) private var systemColorScheme

    #if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    var isWideScreen: Bool { horizontalSizeClass == .regular }
    #else
    var isWideScreen: Bool { true }
    #endif

    let yellowAccent = Color(red: 255/255, green: 186/255, blue: 0/255)

    // Dynamiska temafärger
    private var isDark: Bool {
        switch selectedTheme {
        case .system: return systemColorScheme == .dark
        case .dark: return true
        case .light: return false
        }
    }

    private var backgroundColor: Color {
        isDark ? Color.black : Color(white: 0.94)
    }

    private var cardBackground: Color {
        isDark ? Color(red: 28/255, green: 28/255, blue: 30/255) : Color.white
    }

    private var primaryTextColor: Color {
        isDark ? .white : Color(white: 0.1)
    }

    var body: some View {
        ZStack {
            backgroundColor
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FLUXINATOR")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(yellowAccent)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(ble.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(ble.connectionStatus)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()

                    // Kugghjulsknapp -> Öppnar Settings
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                }
                .padding()

                // Layout: Side-by-side på iPad/Mac, staplat på iPhone
                if isWideScreen {
                    HStack(spacing: 40) {
                        Spacer()
                        speedometerView(size: 300, strokeWidth: 26)
                        Spacer()
                        VStack(spacing: 24) {
                            controlsView
                        }
                        .frame(maxWidth: 420)
                        .padding(.trailing, 24)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 20) {
                        Spacer()
                        speedometerView(size: 230, strokeWidth: 20)
                        Spacer()
                        controlsView
                    }
                    .padding(.horizontal)
                }
            }
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func speedometerView(size: CGFloat, strokeWidth: CGFloat) -> some View {
        ZStack {
            SpeedometerArc(progress: ble.fanSpeed / 100.0, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            Text("\(Int(ble.fanSpeed))%")
                .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                .foregroundColor(primaryTextColor)
        }
    }

    private var controlsView: some View {
        VStack(spacing: 20) {
            // Slider
            Slider(
                value: Binding(
                    get: { ble.fanSpeed },
                    set: { ble.setFanSpeed($0) }
                ),
                in: 0...100,
                onEditingChanged: { isEditing in
                    if !isEditing {
                        // Skicka garanterat det slutgiltiga värdet utan throttling när fingret släpps
                        WatchSyncManager.shared.sendStateToWatch(
                            fanSpeed: ble.fanSpeed,
                            isRunning: ble.isRunning,
                            rpm: ble.rpm,
                            isConnected: ble.isConnected,
                            force: true
                        )
                    }
                }
            )


            // Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("PRESETS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                HStack(spacing: 10) {
                    ForEach([25, 50, 75, 100], id: \.self) { val in
                        Button(action: {
                            ble.setFanSpeed(Double(val))
                        }) {
                            Text(val == 100 ? "MAX" : "\(val)%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(cardBackground)
                                .foregroundColor(ble.fanSpeed == Double(val) ? yellowAccent : primaryTextColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(ble.fanSpeed == Double(val) ? yellowAccent : Color.clear, lineWidth: 2)
                                )
                                .cornerRadius(10)
                                .shadow(color: isDark ? Color.clear : Color.black.opacity(0.06), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Start / Stop Button
            Button(action: {
                ble.togglePower()
            }) {
                HStack {
                    Image(systemName: "fanblades.fill")
                    Text(ble.isRunning ? "STOP" : "ENGAGE")
                }
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(yellowAccent)
                .foregroundColor(.black)
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
    }
}
