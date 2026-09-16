import SwiftUI

struct SpeedometerArc: View {
    var progress: Double // 0.0 till 1.0
    var lineWidth: CGFloat = 20

    // Gula accentfärgen (#FFBA00) och mörk bärnstensbana (#3A2A00)
    let yellowAccent = Color(red: 255/255, green: 186/255, blue: 0/255)
    let darkTrack    = Color(red: 58/255, green: 42/255, blue: 0/255)

    var body: some View {
        ZStack {
            // Bakgrundsbana: täcker 300° (från kl 7 till kl 5)
            Circle()
                .trim(from: 0.0, to: 0.833)
                .stroke(darkTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(120))

            // Aktiv båge som fylls medurs
            Circle()
                .trim(from: 0.0, to: CGFloat(0.833 * min(max(progress, 0.0), 1.0)))
                .stroke(yellowAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(120))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)
        }
    }
}
