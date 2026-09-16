import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .dark

    let yellowAccent = Color(red: 255/255, green: 186/255, blue: 0/255)

    var body: some View {
        NavigationStack {
            Form {
                // Appearance Section
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Device Info Section
                Section(header: Text("Device Connection")) {
                    HStack {
                        Text("Device Name")
                        Spacer()
                        Text("Fluxinator")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Protocol")
                        Spacer()
                        Text("Nordic UART (BLE)")
                            .foregroundColor(.gray)
                    }
                }

                // About Section
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif

            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(yellowAccent)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
