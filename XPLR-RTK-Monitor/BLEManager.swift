import Foundation
import CoreBluetooth
import Combine

/// BLE Manager for XPLR-HPG2-RTK board communication
class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var statusText = "Disconnected"
    @Published var fixType = "NoFix"
    @Published var satellites: Int = 0
    @Published var accuracy: Double = 0.0
    @Published var speed: Double = 0.0
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var lastGGA = ""
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var ntripActive = false
    @Published var heading: Double = 0.0  // degrees, 0 = north
    
    private var prevLatitude: Double = 0
    private var prevLongitude: Double = 0
    
    // MARK: - BLE UUIDs
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let nmeaCharUUID = CBUUID(string: "12345678-1234-1234-1234-123456780001")
    private let controlCharUUID = CBUUID(string: "12345678-1234-1234-1234-123456780002")
    private let statusCharUUID = CBUUID(string: "12345678-1234-1234-1234-123456780003")
    
    // MARK: - Private
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var controlCharacteristic: CBCharacteristic?
    private var nmeaBuffer = ""
    
    // MARK: - Commands
    static let CMD_SHUTDOWN: UInt8 = 0x01
    static let CMD_RESTART: UInt8 = 0x02
    static let CMD_NTRIP_START: UInt8 = 0x03
    static let CMD_NTRIP_STOP: UInt8 = 0x04
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        discoveredDevices = []
        // Scan for all BLE devices (filter by name after discovery)
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        statusText = "Scanning..."
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        statusText = "Connecting..."
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func sendShutdown() {
        sendCommand(BLEManager.CMD_SHUTDOWN)
    }
    
    func sendRestart() {
        sendCommand(BLEManager.CMD_RESTART)
    }
    
    func sendNtripStart() {
        sendCommand(BLEManager.CMD_NTRIP_START)
        ntripActive = true
    }
    
    func sendNtripStop() {
        sendCommand(BLEManager.CMD_NTRIP_STOP)
        ntripActive = false
    }
    
    private func sendCommand(_ cmd: UInt8) {
        guard let characteristic = controlCharacteristic,
              let peripheral = connectedPeripheral else { return }
        let data = Data([cmd])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    // MARK: - NMEA Parsing
    
    private func parseGGA(_ sentence: String) {
        // $GNGGA,065317.30,5112.5413989,N,00658.6641966,E,1,05,4.23,146.882,M,...
        print("[NMEA] \(sentence)")
        let parts = sentence.components(separatedBy: ",")
        guard parts.count >= 10, parts[0].hasSuffix("GGA") else { return }
        
        // Parse latitude: DDMM.MMMMMMM
        if let latRaw = Double(parts[2]), !parts[2].isEmpty {
            let latDeg = floor(latRaw / 100.0)
            let latMin = latRaw - (latDeg * 100.0)
            var lat = latDeg + (latMin / 60.0)
            if parts[3] == "S" { lat = -lat }
            latitude = lat
        }
        
        // Parse longitude: DDDMM.MMMMMMM
        if let lonRaw = Double(parts[4]), !parts[4].isEmpty {
            let lonDeg = floor(lonRaw / 100.0)
            let lonMin = lonRaw - (lonDeg * 100.0)
            var lon = lonDeg + (lonMin / 60.0)
            if parts[5] == "W" { lon = -lon }
            longitude = lon
        }
        
        // Parse fix quality
        if let quality = Int(parts[6]) {
            switch quality {
            case 0: fixType = "NoFix"
            case 1: fixType = "3D"
            case 2: fixType = "DGPS"
            case 4: fixType = "RTK-Fixed"
            case 5: fixType = "RTK-Float"
            case 6: fixType = "DR"
            default: fixType = "Unknown"
            }
        }
        
        // Parse satellites
        if let sats = Int(parts[7]) {
            satellites = sats
        }
        
        // Calculate heading from movement
        if prevLatitude != 0 && prevLongitude != 0 {
            let dLat = latitude - prevLatitude
            let dLon = longitude - prevLongitude
            // Only update heading if we moved enough (avoid jitter when stationary)
            let distance = sqrt(dLat * dLat + dLon * dLon)
            if distance > 0.000001 {  // ~0.1m
                let rad = atan2(dLon * cos(latitude * .pi / 180), dLat)
                var deg = rad * 180.0 / .pi
                if deg < 0 { deg += 360 }
                heading = deg
            }
        }
        prevLatitude = latitude
        prevLongitude = longitude
        
        lastGGA = sentence
    }
    
    private func parseStatus(_ value: String) {
        // Format: "FixType,Satellites,HAcc_mm,Speed_kmh"
        let parts = value.components(separatedBy: ",")
        guard parts.count >= 4 else { return }
        
        fixType = parts[0]
        satellites = Int(parts[1]) ?? 0
        accuracy = (Double(parts[2]) ?? 0) / 1000.0  // mm to m
        speed = Double(parts[3]) ?? 0.0
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusText = "Ready to scan"
        case .poweredOff:
            statusText = "Bluetooth is off"
        case .unauthorized:
            statusText = "Bluetooth unauthorized"
        default:
            statusText = "Bluetooth unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Only show devices with "XPLR" in the name
        guard let name = peripheral.name, name.contains("XPLR") else { return }
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        isConnected = true
        statusText = "Connected"
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        controlCharacteristic = nil
        statusText = "Disconnected"
        fixType = "NoFix"
        satellites = 0
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusText = "Connection failed"
        isConnected = false
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(
                [nmeaCharUUID, controlCharUUID, statusCharUUID],
                for: service
            )
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for char in characteristics {
            switch char.uuid {
            case nmeaCharUUID:
                peripheral.setNotifyValue(true, for: char)
            case controlCharUUID:
                controlCharacteristic = char
            case statusCharUUID:
                peripheral.setNotifyValue(true, for: char)
                peripheral.readValue(for: char)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case nmeaCharUUID:
            // NMEA data comes in chunks, reassemble
            if let chunk = String(data: data, encoding: .utf8) {
                nmeaBuffer += chunk
                // Process complete sentences (look for $ as start marker)
                while let startRange = nmeaBuffer.range(of: "$"),
                      let endRange = nmeaBuffer.range(of: "\r\n", range: startRange.lowerBound..<nmeaBuffer.endIndex) {
                    let sentence = String(nmeaBuffer[startRange.lowerBound..<endRange.lowerBound])
                    nmeaBuffer = String(nmeaBuffer[endRange.upperBound...])
                    if sentence.contains("GGA") {
                        DispatchQueue.main.async {
                            self.parseGGA(sentence)
                        }
                    }
                }
                // Fallback: if buffer has a complete GGA without \r\n (end of transmission)
                if nmeaBuffer.contains("$") && nmeaBuffer.contains("GGA") && nmeaBuffer.contains("*") {
                    if let starIdx = nmeaBuffer.firstIndex(of: "$") {
                        let sentence = String(nmeaBuffer[starIdx...])
                        // Check if checksum is complete (2 hex chars after *)
                        if let astIdx = sentence.lastIndex(of: "*"),
                           sentence.distance(from: astIdx, to: sentence.endIndex) >= 3 {
                            DispatchQueue.main.async {
                                self.parseGGA(sentence)
                            }
                            nmeaBuffer = ""
                        }
                    }
                }
                // Prevent buffer overflow
                if nmeaBuffer.count > 1024 {
                    nmeaBuffer = ""
                }
            }
            
        case statusCharUUID:
            if let value = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.parseStatus(value)
                }
            }
            
        default:
            break
        }
    }
}
