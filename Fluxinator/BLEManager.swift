import Foundation
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEManager()

    // Nordic UART Service UUIDs
    let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let rxUUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let txUUID      = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?

    @Published var isConnected = false
    @Published var connectionStatus = "SEARCHING..."
    @Published var fanSpeed: Double = 0.0
    @Published var isRunning = false
    @Published var rpm: Int = 0
    @Published var isReviewMode: Bool = false

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Central Manager Lifecycle

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            connectionStatus = "SCANNING..."
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        } else {
            isConnected = false
            connectionStatus = "BLUETOOTH OFF"
            syncWithWatch()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Kontrollera att det är Fluxinator som upptäckts
        let discoveredName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        if !discoveredName.isEmpty && !discoveredName.localizedCaseInsensitiveContains("Fluxinator") {
            return
        }

        print("[BLE iPhone] Discovered target: \(discoveredName.isEmpty ? "Fluxinator" : discoveredName)")
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.stopScan()
        connectionStatus = "CONNECTING..."
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "CONNECTED"
        syncWithWatch()
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "DISCONNECTED"
        self.rxCharacteristic = nil
        syncWithWatch()
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    // MARK: - Peripheral Discovery & Data Handling

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([rxUUID, txUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == rxUUID {
                self.rxCharacteristic = characteristic
                sendCommand("STATUS")
            } else if characteristic.uuid == txUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let string = String(data: data, encoding: .utf8) else { return }
        parseResponse(string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func parseResponse(_ text: String) {
        let upper = text.uppercased()

        if upper.contains("OFF") || upper.contains("AV") {
            isRunning = false
            fanSpeed = 0
            rpm = 0
        } else if upper.contains("FAN:") || upper.contains("FLAKT:") {
            let pattern = #"(?:FAN:|FLAKT:)\s*(\d+)"#
            if let range = upper.range(of: pattern, options: .regularExpression) {
                let match = String(upper[range])
                let digits = match.filter { "0123456789".contains($0) }
                if let val = Double(digits) {
                    let clamped = min(max(val, 0.0), 100.0)
                    fanSpeed = clamped
                    isRunning = clamped > 0
                    rpm = Int(clamped * 18.5)
                }
            }
        }

        syncWithWatch()
    }

    // MARK: - Commands

    func sendCommand(_ command: String) {
        guard isConnected, let rx = rxCharacteristic, let peripheral = peripheral else { return }
        let payload = "\(command)\n"
        if let data = payload.data(using: .utf8) {
            let writeType: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            peripheral.writeValue(data, for: rx, type: writeType)
        }
    }

    func setFanSpeed(_ percent: Double) {
        fanSpeed = percent
        rpm = Int(percent * 18.5)
        sendCommand("F \(Int(percent))")
        syncWithWatch()
    }

    func togglePower() {
        isRunning.toggle()
        
        if isRunning {
            // Om hastigheten råkar vara 0 vid start ges ett startvärde (25%),
            // annars behålls det befintliga värdet (t.ex. 10%)
            if fanSpeed == 0 {
                fanSpeed = 25
            }
            rpm = Int(fanSpeed * 18.5)
            sendCommand("F \(Int(fanSpeed))")
        } else {
            sendCommand("OFF")
        }
        
        // Tvinga ut aktuell status till klockan direkt
        #if os(iOS)
        WatchSyncManager.shared.sendStateToWatch(
            fanSpeed: fanSpeed,
            isRunning: isRunning,
            rpm: rpm,
            isConnected: isConnected,
            force: true
        )
        #endif
    }


    
    // Lägg till denna metod i BLEManager:
    func toggleReviewMode() {
        isReviewMode.toggle()
        
        if isReviewMode {
            isConnected = true
            connectionStatus = "CONNECTED"
            print("[REVIEW MODE] Activated - Mock hardware connected.")
        } else {
            isConnected = false
            connectionStatus = "DISCONNECTED"
            print("[REVIEW MODE] Deactivated.")
        }
        
        // Spegla statusen till Apple Watch direkt
        WatchSyncManager.shared.sendStateToWatch(
            fanSpeed: fanSpeed,
            isRunning: isRunning,
            rpm: rpm,
            isConnected: isConnected,
            force: true
        )
    }

    // MARK: - Watch Sync

    private func syncWithWatch() {
        #if os(iOS)
        WatchSyncManager.shared.sendStateToWatch(
            fanSpeed: fanSpeed,
            isRunning: isRunning,
            rpm: rpm,
            isConnected: isConnected
        )
        #endif
    }
}
