import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var ble = BLEManager()
    @State private var showShutdownAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map
                MapView(latitude: ble.latitude, longitude: ble.longitude, fixType: ble.fixType, heading: ble.heading)
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
                            Button(action: {
                                if ble.ntripActive {
                                    ble.sendNtripStop()
                                } else {
                                    ble.sendNtripStart()
                                }
                            }) {
                                Label(ble.ntripActive ? "RTK On" : "RTK Off",
                                      systemImage: ble.ntripActive ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ble.ntripActive ? .green : .gray)
                            
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
    let heading: Double
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.209, longitude: 6.978),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    @State private var mapType: MKMapType = .hybrid
    @State private var showRailOverlay = false
    @State private var followMode = true
    @State private var markerStyle = "crosshair"  // "crosshair", "car", "train"
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapViewRepresentable(
                region: $region,
                mapType: $mapType,
                showRailOverlay: $showRailOverlay,
                followMode: $followMode,
                markerStyle: markerStyle,
                heading: heading,
                annotations: annotations,
                fixType: fixType
            )
            
            // Map controls
            VStack(spacing: 8) {
                Button(action: {
                    switch mapType {
                    case .standard: mapType = .hybrid
                    case .hybrid: mapType = .satellite
                    default: mapType = .standard
                    }
                }) {
                    Image(systemName: mapType == .standard ? "globe" : mapType == .hybrid ? "map" : "globe.americas")
                        .padding(10)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                }
                
                Button(action: { showRailOverlay.toggle() }) {
                    Image(systemName: "tram.fill")
                        .padding(10)
                        .background(showRailOverlay ? Color.orange.opacity(0.8) : Color(.systemBackground).opacity(0.8))
                        .foregroundColor(showRailOverlay ? .white : .primary)
                        .cornerRadius(8)
                }
                
                // Marker style toggle
                Button(action: {
                    switch markerStyle {
                    case "crosshair": markerStyle = "car"
                    case "car": markerStyle = "train"
                    default: markerStyle = "crosshair"
                    }
                }) {
                    Image(systemName: markerStyle == "crosshair" ? "scope" : markerStyle == "car" ? "car.fill" : "tram.fill")
                        .padding(10)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                }
                
                // Recenter button
                Button(action: {
                    followMode = true
                    if latitude != 0, longitude != 0 {
                        region.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    }
                }) {
                    Image(systemName: followMode ? "location.fill" : "location")
                        .padding(10)
                        .background(followMode ? Color.blue.opacity(0.8) : Color(.systemBackground).opacity(0.8))
                        .foregroundColor(followMode ? .white : .primary)
                        .cornerRadius(8)
                }
            }
            .padding(8)
        }
        .onChange(of: latitude) { _ in
            if followMode { updateRegion() }
        }
        .onChange(of: longitude) { _ in
            if followMode { updateRegion() }
        }
    }
    
    private var annotations: [LocationAnnotation] {
        guard latitude != 0, longitude != 0 else { return [] }
        return [LocationAnnotation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))]
    }
    
    private func updateRegion() {
        guard latitude != 0, longitude != 0 else { return }
        region.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - MKMapView UIKit Wrapper

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @Binding var showRailOverlay: Bool
    @Binding var followMode: Bool
    let markerStyle: String
    let heading: Double
    let annotations: [LocationAnnotation]
    let fixType: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.mapType = mapType
        
        // Add pan gesture recognizer to detect user interaction
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.userDidPan))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.userDidPan))
        pinchGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(pinchGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
        context.coordinator.parent = self
        
        // Update region only in follow mode
        if followMode {
            let currentCenter = mapView.region.center
            let distance = abs(currentCenter.latitude - region.center.latitude) + abs(currentCenter.longitude - region.center.longitude)
            if distance > 0.00001 {
                mapView.setRegion(region, animated: true)
            }
        }
        
        // Update annotations
        mapView.removeAnnotations(mapView.annotations)
        for annotation in annotations {
            let pin = MKPointAnnotation()
            pin.coordinate = annotation.coordinate
            mapView.addAnnotation(pin)
        }
        
        // Update OpenRailwayMap overlay
        let hasRailOverlay = mapView.overlays.contains(where: { $0 is MKTileOverlay })
        if showRailOverlay && !hasRailOverlay {
            let railOverlay = MKTileOverlay(urlTemplate: "https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png")
            railOverlay.canReplaceMapContent = false
            railOverlay.maximumZ = 19
            railOverlay.tileSize = CGSize(width: 256, height: 256)
            mapView.addOverlay(railOverlay, level: .aboveLabels)
        } else if !showRailOverlay && hasRailOverlay {
            let railOverlays = mapView.overlays.filter { $0 is MKTileOverlay }
            mapView.removeOverlays(railOverlays)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapViewRepresentable
        
        init(parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        @objc func userDidPan() {
            DispatchQueue.main.async {
                self.parent.followMode = false
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let id = "position"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            }
            view?.annotation = annotation
            
            // Use PNG marker images
            let imageName: String
            switch self.parent.markerStyle {
            case "car": imageName = "marker_car"
            case "train": imageName = "marker_train"
            default: imageName = "marker_crosshair"
            }
            
            if let markerImage = UIImage(named: imageName) {
                // Scale to display size
                let displaySize = CGSize(width: 50, height: 50)
                let renderer = UIGraphicsImageRenderer(size: displaySize)
                let heading = self.parent.heading
                
                view?.image = renderer.image { ctx in
                    // For side-view markers: flip horizontally if heading is west-ish (90-270)
                    if imageName != "marker_crosshair" && heading > 90 && heading < 270 {
                        // Flip horizontally (vehicle going left)
                        ctx.cgContext.translateBy(x: displaySize.width, y: 0)
                        ctx.cgContext.scaleBy(x: -1, y: 1)
                    }
                    markerImage.draw(in: CGRect(origin: .zero, size: displaySize))
                }
            }
            
            // No rotation for side-view (only flip handled above)
            view?.transform = .identity
            
            view?.centerOffset = CGPoint(x: 0, y: 0)
            return view
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
