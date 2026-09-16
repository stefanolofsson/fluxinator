import SwiftUI

struct WatchContentView: View {
    @StateObject private var sync = WatchSyncManager.shared
    @State private var crownAccumulator: Double = 0.0
    @State private var isReceivingFromPhone: Bool = false
    @FocusState private var isFocused: Bool

    let yellowAccent = Color(red: 255/255, green: 186/255, blue: 0/255)

    var body: some View {
        VStack(spacing: 4) {
            // Header
            HStack {
                Text("FLUXINATOR")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(yellowAccent)
                Spacer()
                Circle()
                    .fill(sync.isPhoneConnectedToBLE ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 4)

            // Speedometer Arc
            ZStack {
                SpeedometerArc(progress: sync.fanSpeed / 100.0, lineWidth: 14)
                    .frame(width: 125, height: 125)

                Text("\(Int(sync.fanSpeed))%")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()

            // Start / Stop-knapp
            Button(action: {
                sync.sendCommandToPhone(action: "TOGGLE_POWER")
            }) {
                Text(sync.isRunning ? "STOP" : "START")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(yellowAccent)
                    .foregroundColor(.black)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .focusable()
        .focused($isFocused)
        .digitalCrownRotation(
            $crownAccumulator,
            from: 0.0,
            through: 100.0,
            by: 5.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownAccumulator) { _, newValue in
            // Skicka endast om vridningen gjordes manuellt på klockan
            if !isReceivingFromPhone {
                if abs(newValue - sync.fanSpeed) >= 2.0 {
                    sync.sendCommandToPhone(action: "SET_SPEED", value: newValue)
                }
            }
        }
        .onChange(of: sync.fanSpeed) { _, newSpeed in
            // Synka kronans ackumulator utan att trigga återsändning
            if abs(crownAccumulator - newSpeed) >= 2.0 {
                isReceivingFromPhone = true
                crownAccumulator = newSpeed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isReceivingFromPhone = false
                }
            }
        }
        .onAppear {
            crownAccumulator = sync.fanSpeed
            isFocused = true
        }
    }
}
