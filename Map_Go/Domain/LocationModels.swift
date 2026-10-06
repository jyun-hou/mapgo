import Foundation
import CoreLocation

struct GeoCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) throws {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw LocationError.invalidCoordinate
        }
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) throws {
        try self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    static func parse(latitude latitudeText: String, longitude longitudeText: String) throws -> GeoCoordinate {
        let latitudeValue = Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines))
        let longitudeValue = Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let latitudeValue, let longitudeValue else { throw LocationError.invalidCoordinate }
        return try GeoCoordinate(latitude: latitudeValue, longitude: longitudeValue)
    }

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum LocationSource: String, Sendable {
    case initial
    case route
    case joystick
    case target
}

struct LocationSnapshot: Equatable, Sendable {
    let coordinate: GeoCoordinate
    let source: LocationSource
    let updatedAt: Date
}

enum DevicePlatform: String, Sendable {
    case iOS
}

enum DeviceConnectionState: String, Sendable {
    case connected
    case authorizationRequired
    case disconnected
}

struct DeviceSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let model: String?
    let platform: DevicePlatform
    let hostName: String?
    var state: DeviceConnectionState

    var isReady: Bool { state == .connected }
}

struct SearchResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let coordinate: GeoCoordinate
}

struct RoutePath: Equatable, Sendable {
    let coordinates: [GeoCoordinate]
    let distanceMeters: Double
    let expectedDuration: TimeInterval

    var isEmpty: Bool { coordinates.isEmpty }
}

enum SimulationMode: String, CaseIterable, Identifiable, Sendable {
    case route
    case joystick

    var id: String { rawValue }
    var title: String {
        switch self {
        case .route: "點到點"
        case .joystick: "搖桿"
        }
    }
}

enum SimulationState: Equatable, Sendable {
    case noDevice
    case scanning
    case ready
    case routePlanning
    case routeRunning
    case routePaused
    case manualControl
    case disconnected
    case error(String)

    var title: String {
        switch self {
        case .noDevice: "未選擇裝置"
        case .scanning: "掃描中"
        case .ready: "就緒"
        case .routePlanning: "規劃路徑中"
        case .routeRunning: "路徑移動中"
        case .routePaused: "已暫停"
        case .manualControl: "手動控制中"
        case .disconnected: "裝置已斷線"
        case .error(let message): message
        }
    }
}

enum LocationError: LocalizedError, Equatable, Sendable {
    case invalidCoordinate
    case invalidSpeed
    case speedExceedsMaximum
    case noDevice
    case deviceUnavailable
    case authorizationRequired
    case noSearchResult
    case routeUnavailable
    case controlUnavailable
    case cancelled
    case serviceFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidCoordinate: "座標格式或範圍無效。"
        case .invalidSpeed: "速度必須大於 0。"
        case .speedExceedsMaximum: "速度不可超過 60 km/h。"
        case .noDevice: "請先選擇裝置。"
        case .deviceUnavailable: "裝置目前不可控制。"
        case .authorizationRequired: "裝置需要授權或開發者模式。"
        case .noSearchResult: "找不到地址。"
        case .routeUnavailable: "目前無法規劃路徑。"
        case .controlUnavailable: "目前控制模式不可用。"
        case .cancelled: "操作已取消。"
        case .serviceFailure(let message): message
        }
    }
}

enum MovementCalculator {
    static let maximumSpeedKmh = 60.0
    static let joystickUpdateInterval: TimeInterval = 1.0

    static func speedMetersPerSecond(fromKilometersPerHour value: Double) throws -> Double {
        guard value > 0 else { throw LocationError.invalidSpeed }
        guard value <= maximumSpeedKmh else { throw LocationError.speedExceedsMaximum }
        return value / 3.6
    }

    static func coordinate(
        from origin: GeoCoordinate,
        direction: JoystickDirection,
        intensity: Double,
        metersPerUpdate: Double
    ) throws -> GeoCoordinate {
        let clampedIntensity = min(max(intensity, 0), 1)
        let northMeters = direction.northComponent * metersPerUpdate * clampedIntensity
        let eastMeters = direction.eastComponent * metersPerUpdate * clampedIntensity
        let latitudeDelta = northMeters / 111_320
        let longitudeScale = max(cos(origin.latitude * .pi / 180) * 111_320, 1)
        let longitudeDelta = eastMeters / longitudeScale
        return try GeoCoordinate(latitude: origin.latitude + latitudeDelta,
                                 longitude: origin.longitude + longitudeDelta)
    }
}

struct JoystickDirection: Equatable, Sendable {
    let northComponent: Double
    let eastComponent: Double

    init(north: Double, east: Double) {
        let length = max(sqrt(north * north + east * east), 1)
        northComponent = north / length
        eastComponent = east / length
    }
}
