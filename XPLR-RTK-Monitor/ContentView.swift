import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var ble = BLEManager()
    @State private var showShutdownAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map
                MapView(latitude: ble.latitude, longitude: ble.longitude, fixType: ble.fixType)
                    .frame(maxHeight: .infinity)
                
                // Status Panel
                VStack(spacing: 12) {
                    // Fix Status Badge
                    HStack {
                        FixBadge(fixType: ble.fixType)
                        Spacer()
                        ConnectionBadge(isConnected: ble.isConnected)
                    }
                    
                    // Stats Row
                    HStack(spacing: 20) {
                        StatItem(icon: "satellite.fill", value: "\(ble.satellites)", label: "Sats")
                        StatItem(icon: "scope", value: String(format: "%.2f m", ble.accuracy), label: "Accuracy")
                        StatItem(icon: "speedometer", value: String(format: "%.1f km/h", ble.speed), label: "Speed")
                    }
                    
                    // Coordinates
                    if ble.latitude != 0 {
                        Text(String(format: "%.7f, %.7f", ble.latitude, ble.longitude))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    // Buttons
                    HStack(spacing: 16) {
                        if ble.isConnected {
                            Button(action: { ble.disconnect() }) {
                                Label("Disconnect", systemImage: "antenna.radiowaves.left.and.right.slash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: { showShutdownAlert = true }) {
                                Label("Shutdown", systemImage: "power")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button(action: { ble.startScanning() }) {
                                Label(ble.isScanning ? "Scanning..." : "Scan", systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(ble.isScanning)
                        }
                    }
                    
                    // Device List (when scanning)
                    if !ble.discoveredDevices.isEmpty && !ble.isConnected {
                        ForEach(ble.discoveredDevices, id: \.identifier) { device in
                            Button(action: { ble.connect(to: device) }) {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                    Text(device.name ?? "Unknown")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("XPLR RTK Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Board herunterfahren?", isPresented: $showShutdownAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Shutdown", role: .destructive) {
                    ble.sendShutdown()
                }
            } message: {
                Text("Das Board wird sauber heruntergefahren. SD-Karte wird geschlossen.")
            }
        }
    }
}

// MARK: - Map View

struct MapView: View {
    let latitude: Double
    let longitude: Double
    let fixType: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.209, longitude: 6.978),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                Circle()
                    .fill(colorForFix(fixType))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
        }
        .onChange(of: latitude) { _ in updateRegion() }
        .onChange(of: longitude) { _ in updateRegion() }
    }
    
    private var annotations: [LocationAnnotation] {
        guard latitude != 0, longitude != 0 else { return [] }
        return [LocationAnnotation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))]
    }
    
    private func updateRegion() {
        guard latitude != 0, longitude != 0 else { return }
        withAnimation {
            region.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    private func colorForFix(_ fix: String) -> Color {
        switch fix {
        case "RTK-Fixed": return .green
        case "RTK-Float": return .orange
        case "3D", "DGPS": return .blue
        case "DR": return .purple
        default: return .red
        }
    }
}

struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - UI Components

struct FixBadge: View {
    let fixType: String
    
    var body: some View {
        Text(fixType)
            .font(.system(.headline, design: .rounded))
            .fontWeight(.bold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorForFix.opacity(0.2))
            .foregroundColor(colorForFix)
            .cornerRadius(8)
    }
    
    private var colorForFix: Color {
        switch fixType {
        case "RTK-Fixed": return .green
        case "RTK-Float": return .orange
        case "3D", "DGPS": return .blue
        case "DR": return .purple
        default: return .red
        }
    }
}

struct ConnectionBadge: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Offline")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
}
