import Foundation
import CoreLocation

protocol DeviceProvider: Sendable {
    func scan() async throws -> [DeviceSummary]
}

protocol LocationController: Sendable {
    func send(location: GeoCoordinate, to device: DeviceSummary) async throws
}

protocol Geocoder: Sendable {
    func search(address: String) async throws -> [SearchResult]
}

protocol RoutePlanner: Sendable {
    func route(from: GeoCoordinate, to: GeoCoordinate) async throws -> RoutePath
}

struct FakeDeviceProvider: DeviceProvider {
    func scan() async throws -> [DeviceSummary] {
        [
            DeviceSummary(id: "demo-iphone", name: "Demo iPhone", model: "iPhone", platform: .iOS, hostName: nil, state: .connected),
            DeviceSummary(id: "demo-ipad", name: "Demo iPad", model: "iPad", platform: .iOS, hostName: nil, state: .authorizationRequired)
        ]
    }
}

struct FakeLocationController: LocationController {
    func send(location: GeoCoordinate, to device: DeviceSummary) async throws {
        guard device.isReady else { throw LocationError.deviceUnavailable }
    }
}

struct FakeGeocoder: Geocoder {
    func search(address: String) async throws -> [SearchResult] {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LocationError.noSearchResult }
        let coordinate = try GeoCoordinate(latitude: 25.0330, longitude: 121.5654)
        return [SearchResult(id: UUID(), title: address, subtitle: "Demo result", coordinate: coordinate)]
    }
}

struct FakeRoutePlanner: RoutePlanner {
    func route(from start: GeoCoordinate, to end: GeoCoordinate) async throws -> RoutePath {
        let coordinates = stride(from: 0.0, through: 1.0, by: 0.1).map { progress in
            try! GeoCoordinate(latitude: start.latitude + (end.latitude - start.latitude) * progress,
                               longitude: start.longitude + (end.longitude - start.longitude) * progress)
        }
        let distance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        return RoutePath(coordinates: coordinates, distanceMeters: distance, expectedDuration: distance / 5)
    }
}

struct EmptyDeviceProvider: DeviceProvider {
    func scan() async throws -> [DeviceSummary] { [] }
}

struct NoResultGeocoder: Geocoder {
    func search(address: String) async throws -> [SearchResult] { throw LocationError.noSearchResult }
}

struct FailingRoutePlanner: RoutePlanner {
    func route(from: GeoCoordinate, to: GeoCoordinate) async throws -> RoutePath {
        throw LocationError.routeUnavailable
    }
}

struct FailingLocationController: LocationController {
    func send(location: GeoCoordinate, to device: DeviceSummary) async throws {
        throw LocationError.serviceFailure("Fake 裝置已斷線。")
    }
}
