enum DeviceSessionEvent: Sendable {
    case scanRequested
    case devicesLoaded(hasReadyDevice: Bool)
    case routePlanningStarted
    case routeReady
    case routeStarted
    case routePaused
    case routeStopped(hasDevice: Bool)
    case joystickStarted
    case joystickStopped
    case disconnected
    case failed(String)
}

struct DeviceSessionStateMachine: Sendable {
    private(set) var state: SimulationState = .noDevice

    @discardableResult
    mutating func apply(_ event: DeviceSessionEvent) -> Bool {
        let nextState: SimulationState?
        switch (state, event) {
        case (_, .scanRequested):
            nextState = .scanning
        case (.scanning, .devicesLoaded(true)):
            nextState = .ready
        case (.scanning, .devicesLoaded(false)):
            nextState = .noDevice
        case (.ready, .routePlanningStarted):
            nextState = .routePlanning
        case (.routePlanning, .routeReady):
            nextState = .ready
        case (.ready, .routeStarted), (.routePaused, .routeStarted):
            nextState = .routeRunning
        case (.routeRunning, .routePaused):
            nextState = .routePaused
        case (.routeRunning, .routeStopped(let hasDevice)), (.routePaused, .routeStopped(let hasDevice)):
            nextState = hasDevice ? .ready : .noDevice
        case (.ready, .joystickStarted):
            nextState = .manualControl
        case (.manualControl, .joystickStopped):
            nextState = .ready
        case (_, .disconnected):
            nextState = .disconnected
        case (_, .failed(let message)):
            nextState = .error(message)
        default:
            nextState = nil
        }
        guard let nextState else { return false }
        state = nextState
        return true
    }
}
