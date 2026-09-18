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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Inställningssektioner
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Appearance
                    settingsSection(title: "Appearance") {
                        HStack {
                            Text("Theme")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $selectedTheme) {
                                ForEach(AppTheme.allCases) { theme in
                                    Text(theme.rawValue).tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 210)
                        }
                    }

                    // Device Connection
                    settingsSection(title: "Device Connection") {
                        VStack(spacing: 10) {
                            settingsRow(label: "Device Name", value: "Fluxinator")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(label: "Protocol", value: "Nordic UART (BLE)")
                        }
                    }

                    // About
                    settingsSection(title: "About") {
                        settingsRow(label: "App Version", value: "1.0.0")
                    }
                }
                .padding(.horizontal, 20)
            }

            // Footer med Done-knapp
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(yellowAccent)
                .foregroundColor(.black)
                .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.25))
        }
        #if os(macOS)
        .frame(width: 450, height: 380)
        #endif
        .background(Color(red: 24/255, green: 22/255, blue: 20/255))
    }

    // MARK: - Layoutkomponenter

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)

            VStack {
                content()
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
        .font(.system(size: 13))
    }
}
