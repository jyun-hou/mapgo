import Foundation
import CoreLocation
import MapKit

struct AppleGeocoder: Geocoder {
    func search(address: String) async throws -> [SearchResult] {
        let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw LocationError.noSearchResult }
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            let results = placemarks.compactMap { placemark -> SearchResult? in
                guard let location = placemark.location, let coordinate = try? GeoCoordinate(location.coordinate) else { return nil }
                let title = placemark.name ?? query
                let subtitle = [placemark.locality, placemark.administrativeArea].compactMap { $0 }.joined(separator: ", ")
                return SearchResult(id: UUID(), title: title, subtitle: subtitle, coordinate: coordinate)
            }
            guard !results.isEmpty else { throw LocationError.noSearchResult }
            return results
        } catch is CancellationError {
            throw LocationError.cancelled
        } catch let error as LocationError {
            throw error
        } catch {
            throw LocationError.serviceFailure(error.localizedDescription)
        }
    }
}

struct AppleRoutePlanner: RoutePlanner {
    func route(from start: GeoCoordinate, to end: GeoCoordinate) async throws -> RoutePath {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.clLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.clLocation))
        request.transportType = .walking
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { throw LocationError.routeUnavailable }
            var values = Array(repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
            route.polyline.getCoordinates(&values, range: NSRange(location: 0, length: route.polyline.pointCount))
            let path = values.compactMap { try? GeoCoordinate($0) }
            guard !path.isEmpty else { throw LocationError.routeUnavailable }
            return RoutePath(coordinates: path, distanceMeters: route.distance, expectedDuration: route.expectedTravelTime)
        } catch is CancellationError {
            throw LocationError.cancelled
        } catch let error as LocationError {
            throw error
        } catch {
            throw LocationError.serviceFailure(error.localizedDescription)
        }
    }
}

struct UnavailableIOSLocationController: LocationController {
    func send(location: GeoCoordinate, to device: DeviceSummary) async throws {
        throw LocationError.serviceFailure("尚未設定 iOS 模擬定位控制工具；目前可使用 Demo 裝置驗證流程。")
    }
}
