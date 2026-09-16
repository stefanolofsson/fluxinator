import Foundation
import Combine
import SwiftUI

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

class WatchSyncManager: NSObject, ObservableObject {
    static let shared = WatchSyncManager()

    @Published var fanSpeed: Double = 0.0
    @Published var isRunning: Bool = false
    @Published var rpm: Int = 0
    @Published var isPhoneConnectedToBLE: Bool = false

    private var lastSendTime: TimeInterval = 0
    private var lastReceivedTimestamp: Double = 0

    private override init() {
        super.init()
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    // MARK: - Skicka från iPhone/Mac till Watch
    func sendStateToWatch(fanSpeed: Double, isRunning: Bool, rpm: Int, isConnected: Bool, force: Bool = false) {
        self.fanSpeed = fanSpeed
        self.isRunning = isRunning
        self.rpm = rpm
        self.isPhoneConnectedToBLE = isConnected

        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let now = Date().timeIntervalSince1970

        // Strypning: skicka max en gång var 80:e ms om inte force == true
        if !force && (now - lastSendTime) < 0.08 {
            return
        }
        lastSendTime = now

        let context: [String: Any] = [
            "fanSpeed": fanSpeed,
            "isRunning": isRunning,
            "rpm": rpm,
            "isConnected": isConnected,
            "timestamp": now
        ]

        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { _ in }
        } else {
            try? session.updateApplicationContext(context)
        }
        #endif
    }

    // MARK: - Skicka från Watch till iPhone
    func sendCommandToPhone(action: String, value: Double? = nil) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated && session.isReachable else { return }

        var message: [String: Any] = ["action": action]
        if let val = value {
            message["value"] = val
        }

        session.sendMessage(message, replyHandler: nil) { _ in }
        #endif
    }
}

// MARK: - WCSessionDelegate (Aktivt på iOS och watchOS)
#if canImport(WatchConnectivity)
extension WatchSyncManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if os(watchOS)
        if activationState == .activated {
            if !session.receivedApplicationContext.isEmpty {
                handleIncomingData(session.receivedApplicationContext)
            }
            if session.isReachable {
                session.sendMessage(["action": "REQUEST_STATUS"], replyHandler: nil) { _ in }
            }
        }
        #endif
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingData(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingData(applicationContext)
    }

    private func handleIncomingData(_ dict: [String: Any]) {
        DispatchQueue.main.async {
            #if os(watchOS)
            // Ignorera fördröjda paket som är äldre än det senast visade
            if let timestamp = dict["timestamp"] as? Double {
                guard timestamp >= self.lastReceivedTimestamp else { return }
                self.lastReceivedTimestamp = timestamp
            }

            if let speed = dict["fanSpeed"] as? Double { self.fanSpeed = speed }
            if let running = dict["isRunning"] as? Bool { self.isRunning = running }
            if let r = dict["rpm"] as? Int { self.rpm = r }
            if let conn = dict["isConnected"] as? Bool { self.isPhoneConnectedToBLE = conn }
            #elseif os(iOS)
            if let action = dict["action"] as? String {
                switch action {
                case "TOGGLE_POWER":
                    BLEManager.shared.togglePower()
                case "SET_SPEED":
                    if let val = dict["value"] as? Double {
                        BLEManager.shared.setFanSpeed(val)
                    }
                case "REQUEST_STATUS":
                    self.sendStateToWatch(
                        fanSpeed: BLEManager.shared.fanSpeed,
                        isRunning: BLEManager.shared.isRunning,
                        rpm: BLEManager.shared.rpm,
                        isConnected: BLEManager.shared.isConnected,
                        force: true
                    )
                default:
                    break
                }
            }
            #endif
        }
    }
}
#endif
