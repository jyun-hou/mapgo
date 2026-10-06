import Combine
import CoreLocation
import SwiftUI

@MainActor
final class HostLocationModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status = "等待位置…"
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else {
            status = "等待位置權限…"
            return
        }
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let text = String(format: "Location: %.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        Task { @MainActor [weak self] in self?.status = text }
    }
}

@main
struct LocationTestHostApp: App {
    @StateObject private var locationModel = HostLocationModel()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.largeTitle)
                Text("Location Test Host")
                    .font(.headline)
                Text(locationModel.status)
                    .accessibilityIdentifier("location-status")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
