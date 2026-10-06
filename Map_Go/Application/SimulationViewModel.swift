import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
final class SimulationViewModel: ObservableObject {
    @Published private(set) var devices: [DeviceSummary] = []
    @Published var selectedDevice: DeviceSummary?
    @Published private(set) var state: SimulationState = .noDevice
    @Published private(set) var isLoading = false
    @Published var mode: SimulationMode = .route
    @Published var userLocation: GeoCoordinate?
    @Published var currentLocation: LocationSnapshot?
    @Published var targetLocation: GeoCoordinate?
    @Published var routeStartLocation: GeoCoordinate?
    @Published var routeEndLocation: GeoCoordinate?
    @Published var joystickStartLocation: GeoCoordinate?
    @Published var route: RoutePath?
    @Published var errorMessage: String?
    @Published var speedKmh = 10.0
    @Published var addressQuery = ""
    @Published var latitudeText = ""
    @Published var longitudeText = ""
    @Published var ipcHost = ""
    @Published var ipcPortText = "58432"

    let geocoder: any Geocoder
    let routePlanner: any RoutePlanner
    private let deviceProvider: any DeviceProvider
    private let locationController: any LocationController
    private var movementTask: Task<Void, Never>?
    private var joystickTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var routePlanningTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var joystickInput: (JoystickDirection, Double)?
    private var nextRouteIndex = 0
    private var loadingTaskCount = 0

    @MainActor init(deviceProvider: any DeviceProvider, locationController: any LocationController, geocoder: any Geocoder, routePlanner: any RoutePlanner) {
        self.deviceProvider = deviceProvider
        self.locationController = locationController
        self.geocoder = geocoder
        self.routePlanner = routePlanner
    }

    convenience init() {
        self.init(deviceProvider: DevicectlDeviceProvider(), locationController: IOSLocationIPCController(), geocoder: AppleGeocoder(), routePlanner: AppleRoutePlanner())
    }

    convenience init(uiTestScenario: String) {
        switch uiTestScenario {
        case "-UITestNoDevice":
            self.init(deviceProvider: EmptyDeviceProvider(), locationController: FakeLocationController(), geocoder: FakeGeocoder(), routePlanner: FakeRoutePlanner())
        case "-UITestSearchNoResult":
            self.init(deviceProvider: FakeDeviceProvider(), locationController: FakeLocationController(), geocoder: NoResultGeocoder(), routePlanner: FakeRoutePlanner())
        case "-UITestRouteFailure":
            self.init(deviceProvider: FakeDeviceProvider(), locationController: FakeLocationController(), geocoder: FakeGeocoder(), routePlanner: FailingRoutePlanner())
        case "-UITestDisconnected":
            self.init(deviceProvider: FakeDeviceProvider(), locationController: FailingLocationController(), geocoder: FakeGeocoder(), routePlanner: FakeRoutePlanner())
        case "-UITestConflict":
            self.init(deviceProvider: FakeDeviceProvider(), locationController: FakeLocationController(), geocoder: FakeGeocoder(), routePlanner: FakeRoutePlanner())
            selectedDevice = DeviceSummary(id: "ui-test-device", name: "UI Test iPhone", model: "iPhone", platform: .iOS, hostName: nil, state: .connected)
            state = .routeRunning
            if let coordinate = try? GeoCoordinate(latitude: 25.033, longitude: 121.565) {
                currentLocation = LocationSnapshot(coordinate: coordinate, source: .route, updatedAt: .now)
            }
        default:
            self.init()
        }
    }

    deinit {
        scanTask?.cancel()
        routePlanningTask?.cancel()
        searchTask?.cancel()
        movementTask?.cancel()
        joystickTask?.cancel()
    }

    func configureIPC() {
        guard let port = UInt16(ipcPortText), port > 0 else {
            errorMessage = "IPC Port 必須是 1 到 65535。"
            return
        }
        guard let controller = locationController as? IOSLocationIPCController else { return }
        let host = ipcHost
#if DEBUG
        print("[MapGo IPC] configure \(host):\(port)")
#endif
        Task { await controller.configure(host: host, port: port) }
        errorMessage = nil
    }

    func stopAllOperations() {
        scanTask?.cancel()
        routePlanningTask?.cancel()
        searchTask?.cancel()
        movementTask?.cancel()
        joystickTask?.cancel()
        scanTask = nil
        routePlanningTask = nil
        searchTask = nil
        movementTask = nil
        joystickTask = nil
        joystickInput = nil
    }

    func scanDevices() {
        scanTask?.cancel()
        state = .scanning
        errorMessage = nil
        beginLoading()
        scanTask = Task {
            defer { endLoading() }
            do {
                let scannedDevices = try await deviceProvider.scan()
                try Task.checkCancellation()
                devices = scannedDevices
                state = selectedDevice == nil ? .noDevice : .ready
            } catch {
                if Task.isCancelled { return }
                state = .error(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    func select(device: DeviceSummary) {
        guard device.isReady else { errorMessage = LocationError.authorizationRequired.localizedDescription; return }
        selectedDevice = device
        if ipcHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let hostName = device.hostName {
            ipcHost = hostName
        }
        state = .ready
        errorMessage = nil
    }

    func setMode(_ mode: SimulationMode) {
        guard self.mode != mode else { return }
        stopRoute()
        endJoystick()
        self.mode = mode
        route = nil
        errorMessage = nil
        state = selectedDevice == nil ? .noDevice : .ready
    }

    func updateUserLocation(_ coordinate: GeoCoordinate) {
        userLocation = coordinate
        guard movementTask == nil, joystickTask == nil else { return }
        if mode == .route, routeStartLocation == nil { routeStartLocation = coordinate }
        if mode == .joystick, joystickStartLocation == nil { joystickStartLocation = coordinate }
        if currentLocation == nil {
            currentLocation = LocationSnapshot(coordinate: coordinate, source: .initial, updatedAt: .now)
        }
    }

    func useUserLocationAsStart() {
        guard let userLocation else { errorMessage = "尚未取得使用者目前位置。"; return }
        if mode == .route { routeStartLocation = userLocation } else { joystickStartLocation = userLocation }
        currentLocation = LocationSnapshot(coordinate: userLocation, source: .initial, updatedAt: .now)
        route = nil
    }

    func useTargetAsStart() {
        guard let targetLocation else { errorMessage = "請先用地址或座標設定地圖位置。"; return }
        if mode == .route { routeStartLocation = targetLocation } else { joystickStartLocation = targetLocation }
        currentLocation = LocationSnapshot(coordinate: targetLocation, source: .initial, updatedAt: .now)
        route = nil
    }

    func setTarget(_ coordinate: GeoCoordinate) {
        targetLocation = coordinate
        if mode == .route {
            routeEndLocation = coordinate
        } else {
            joystickStartLocation = coordinate
            currentLocation = LocationSnapshot(coordinate: coordinate, source: .initial, updatedAt: .now)
        }
        errorMessage = nil
    }

    func setTargetFromText() {
        guard let coordinate = try? GeoCoordinate.parse(latitude: latitudeText, longitude: longitudeText) else {
            errorMessage = LocationError.invalidCoordinate.localizedDescription
            return
        }
        setTarget(coordinate)
    }

    func searchAddress() {
        searchTask?.cancel()
        beginLoading()
        searchTask = Task {
            defer { endLoading() }
            do {
                let results = try await geocoder.search(address: addressQuery)
                try Task.checkCancellation()
                if let first = results.first { setTarget(first.coordinate) }
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }

    func planRoute() {
        guard selectedDevice?.isReady == true else { errorMessage = LocationError.noDevice.localizedDescription; return }
        guard let start = routeStartLocation, let target = routeEndLocation else { errorMessage = "請先設定開始地點與結束地點。"; return }
        state = .routePlanning
        routePlanningTask?.cancel()
        beginLoading()
        routePlanningTask = Task {
            defer { endLoading() }
            do {
                let plannedRoute = try await routePlanner.route(from: start, to: target)
                try Task.checkCancellation()
                route = plannedRoute
                state = .ready
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    state = .error(error.localizedDescription)
                }
            }
        }
    }

    func startRoute() {
        guard let device = selectedDevice, let route, !route.isEmpty else { errorMessage = LocationError.routeUnavailable.localizedDescription; return }
        guard let speed = try? MovementCalculator.speedMetersPerSecond(fromKilometersPerHour: speedKmh) else { errorMessage = LocationError.invalidSpeed.localizedDescription; return }
        movementTask?.cancel()
        state = .routeRunning
        movementTask = Task { [weak self] in
            guard let self else { return }
            let startIndex = min(nextRouteIndex, route.coordinates.count - 1)
            for index in startIndex..<route.coordinates.count {
                let coordinate = route.coordinates[index]
                if Task.isCancelled { return }
                do {
                    try await locationController.send(location: coordinate, to: device)
                    currentLocation = LocationSnapshot(coordinate: coordinate, source: .route, updatedAt: .now)
                    nextRouteIndex = index + 1
                    if index + 1 < route.coordinates.count {
                        let next = route.coordinates[index + 1]
                        let segmentMeters = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                            .distance(from: CLLocation(latitude: next.latitude, longitude: next.longitude))
                        try await Task.sleep(for: .seconds(max(0.05, segmentMeters / speed)))
                    }
                } catch {
                    if !Task.isCancelled { handleControlFailure(error) }
                    return
                }
            }
            nextRouteIndex = 0
            state = .ready
        }
    }

    func pauseRoute() { movementTask?.cancel(); movementTask = nil; if state == .routeRunning { state = .routePaused } }
    func stopRoute() { movementTask?.cancel(); movementTask = nil; nextRouteIndex = 0; state = selectedDevice == nil ? .noDevice : .ready }

    func updateJoystick(direction: JoystickDirection, intensity: Double) {
        guard mode == .joystick, selectedDevice != nil, state != .routeRunning else { return }
        guard currentLocation != nil else {
            errorMessage = "尚未設定搖桿起始位置，請先選擇地圖目標或使用目前位置。"
            return
        }
        joystickInput = (direction, intensity)
        state = .manualControl
        if joystickTask == nil {
            joystickTask = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    await sendJoystickUpdate()
                    try? await Task.sleep(for: .seconds(MovementCalculator.joystickUpdateInterval))
                }
            }
        }
    }

    func endJoystick(restoreState: Bool = true) {
        let lastInput = joystickInput
        joystickInput = nil
        joystickTask?.cancel()
        joystickTask = nil
        if let lastInput {
            Task { [weak self] in
                await self?.sendJoystickUpdate(input: lastInput)
            }
        }
        if restoreState, selectedDevice?.isReady == true { state = .ready }
    }

    private func sendJoystickUpdate(input: (JoystickDirection, Double)? = nil) async {
        guard let device = selectedDevice,
              let snapshot = currentLocation,
              let (direction, intensity) = input ?? joystickInput else { return }
        do {
            let next = try MovementCalculator.coordinate(from: snapshot.coordinate, direction: direction, intensity: intensity, metersPerUpdate: 5)
            try await locationController.send(location: next, to: device)
            currentLocation = LocationSnapshot(coordinate: next, source: .joystick, updatedAt: .now)
        } catch {
            if !Task.isCancelled {
                handleControlFailure(error)
                endJoystick(restoreState: false)
            }
        }
    }

    private func beginLoading() {
        loadingTaskCount += 1
        isLoading = true
    }

    private func endLoading() {
        loadingTaskCount = max(0, loadingTaskCount - 1)
        isLoading = loadingTaskCount > 0
    }

    private func handleControlFailure(_ error: Error) {
        errorMessage = error.localizedDescription
        if var device = selectedDevice {
            device.state = .disconnected
            selectedDevice = device
        }
        movementTask?.cancel()
        movementTask = nil
        joystickTask?.cancel()
        joystickTask = nil
        state = .disconnected
    }
}
