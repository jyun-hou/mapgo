import Foundation

@main
struct LocationDomainTests {
    static func main() throws {
        try testCoordinateValidationAndParsing()
        try testSpeedValidationAndConversion()
        try testRouteSamplingUsesSpeedAndVirtualTime()
        try testJoystickDirectionIntensityAndCoordinateBoundary()
        testDeviceSessionStateMachineTransitions()
        print("Domain tests passed: 2.3, 2.4, 2.5, 2.6, 3.2")
    }

    private static func testCoordinateValidationAndParsing() throws {
        let southWest = try GeoCoordinate.parse(latitude: " -90 ", longitude: "180")
        let northEast = try GeoCoordinate.parse(latitude: "90", longitude: "-180")
        let expectedSouthWest = try GeoCoordinate(latitude: -90, longitude: 180)
        let expectedNorthEast = try GeoCoordinate(latitude: 90, longitude: -180)
        precondition(southWest == expectedSouthWest)
        precondition(northEast == expectedNorthEast)
        expectError { _ = try GeoCoordinate.parse(latitude: "north", longitude: "121.5") }
        expectError { _ = try GeoCoordinate(latitude: 90.000001, longitude: 0) }
        expectError { _ = try GeoCoordinate(latitude: 0, longitude: -180.000001) }
        print("✓ 2.3 coordinate validation")
    }

    private static func testSpeedValidationAndConversion() throws {
        let oneMeterPerSecond = try MovementCalculator.speedMetersPerSecond(fromKilometersPerHour: 3.6)
        let maximumSpeed = try MovementCalculator.speedMetersPerSecond(fromKilometersPerHour: 60)
        precondition(abs(oneMeterPerSecond - 1) < 0.000001)
        precondition(abs(maximumSpeed - 16.6666667) < 0.000001)
        expectError { _ = try MovementCalculator.speedMetersPerSecond(fromKilometersPerHour: 0) }
        expectError { _ = try MovementCalculator.speedMetersPerSecond(fromKilometersPerHour: -1) }
        expectError { _ = try MovementCalculator.speedMetersPerSecond(fromKilometersPerHour: 60.000001) }
        print("✓ 2.4 speed validation and conversion")
    }

    private static func testRouteSamplingUsesSpeedAndVirtualTime() throws {
        let start = try GeoCoordinate(latitude: 25, longitude: 121)
        let end = try GeoCoordinate(latitude: 25, longitude: 121.001)
        let route = RoutePath(coordinates: [start, end], distanceMeters: 0, expectedDuration: 0)
        let halfway = try RouteSampler.coordinate(on: route, elapsed: 5, speedMetersPerSecond: 10)
        precondition(halfway.longitude > start.longitude && halfway.longitude < end.longitude)
        let completed = try RouteSampler.coordinate(on: route, elapsed: 10_000, speedMetersPerSecond: 10)
        let beforeStart = try RouteSampler.coordinate(on: route, elapsed: -1, speedMetersPerSecond: 10)
        precondition(completed == end)
        precondition(beforeStart == start)
        print("✓ 2.5 route sampling and virtual time")
    }

    private static func testJoystickDirectionIntensityAndCoordinateBoundary() throws {
        let origin = try GeoCoordinate(latitude: 25, longitude: 121)
        let north = try MovementCalculator.coordinate(from: origin, direction: JoystickDirection(north: 1, east: 0), intensity: 1, metersPerUpdate: 10)
        precondition(north.latitude > origin.latitude)
        precondition(abs(north.longitude - origin.longitude) < 0.0000001)
        let clamped = try MovementCalculator.coordinate(from: origin, direction: JoystickDirection(north: 0, east: 1), intensity: 2, metersPerUpdate: 10)
        let full = try MovementCalculator.coordinate(from: origin, direction: JoystickDirection(north: 0, east: 1), intensity: 1, metersPerUpdate: 10)
        precondition(clamped == full)
        let nearNorthPole = try GeoCoordinate(latitude: 89.99995, longitude: 0)
        expectError { _ = try MovementCalculator.coordinate(from: nearNorthPole, direction: JoystickDirection(north: 1, east: 0), intensity: 1, metersPerUpdate: 10) }
        print("✓ 2.6 joystick direction, intensity, and boundaries")
    }

    private static func testDeviceSessionStateMachineTransitions() {
        var machine = DeviceSessionStateMachine()
        precondition(machine.apply(.scanRequested))
        precondition(machine.state == .scanning)
        precondition(machine.apply(.devicesLoaded(hasReadyDevice: true)))
        precondition(machine.state == .ready)
        precondition(machine.apply(.routePlanningStarted))
        precondition(machine.apply(.routeReady))
        precondition(machine.apply(.routeStarted))
        precondition(machine.apply(.routePaused))
        precondition(machine.apply(.routeStarted))
        precondition(machine.apply(.routeStopped(hasDevice: true)))
        precondition(machine.apply(.joystickStarted))
        precondition(machine.apply(.joystickStopped))
        precondition(machine.apply(.disconnected))
        precondition(!machine.apply(.routeStarted))
        print("✓ 3.2 device session state machine")
    }

    private static func expectError(_ operation: () throws -> Void) {
        do {
            _ = try operation()
            preconditionFailure("Expected operation to fail")
        } catch {
            // Expected validation failure.
        }
    }
}
