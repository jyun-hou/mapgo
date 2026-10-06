import CoreLocation
import Network
import XCTest

private struct LocationIPCCommand: Decodable {
    let type: String
    let requestID: UUID
    let latitude: Double
    let longitude: Double
}

private struct LocationIPCResponse: Encodable {
    let requestID: UUID
    let success: Bool
    let message: String?
}

private final class LocationIPCListener {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.mapgo.location-test-runner-ipc")
    private let onLocation: (CLLocation) -> Void
    private let onFailure: (Error) -> Void

    init(port: UInt16, onLocation: @escaping (CLLocation) -> Void, onFailure: @escaping (Error) -> Void) throws {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "LocationIPC", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid IPC port."])
        }
        listener = try NWListener(using: .tcp, on: port)
        self.onLocation = onLocation
        self.onFailure = onFailure
    }

    func start() {
        listener.stateUpdateHandler = { state in
            print("[LocationIPC] listener state: \(state)")
            if case .failed(let error) = state {
                DispatchQueue.main.async { self.onFailure(error) }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            print("[LocationIPC] connection accepted")
            self?.receive(on: connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener.cancel()
    }

    private func receive(on connection: NWConnection, buffer: Data = Data()) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { [weak self] data, _, isComplete, error in
            guard let self, error == nil else {
                connection.cancel()
                return
            }

            let received = buffer + (data ?? Data())
            guard let newline = received.firstIndex(of: 0x0A) else {
                guard !isComplete else { connection.cancel(); return }
                self.receive(on: connection, buffer: received)
                return
            }
            let message = received[..<newline]
            guard let command = try? JSONDecoder().decode(LocationIPCCommand.self, from: message), command.type == "setLocation" else {
                connection.cancel()
                return
            }

            DispatchQueue.main.async {
                print("[LocationIPC] received location: \(command.latitude), \(command.longitude)")
                self.onLocation(CLLocation(latitude: command.latitude, longitude: command.longitude))
                let response = LocationIPCResponse(requestID: command.requestID, success: true, message: nil)
                let responseData = (try? JSONEncoder().encode(response)).map { $0 + Data([0x0A]) }
                connection.send(content: responseData, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }
}

final class FixedLocationUITests: XCTestCase {
    func testSetFixedLocationOnDevice() {
        XCUIDevice.shared.location = XCUILocation(
            location: CLLocation(latitude: 25.0330, longitude: 121.5654)
        )

        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Location Test Host"].waitForExistence(timeout: 10),
            "測試 App 沒有成功啟動；請確認實體 iPhone 已配對且簽章設定完成。"
        )

        let locationStatus = app.staticTexts["location-status"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS '25.0330'"),
            object: locationStatus
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed,
                       "Host App 沒有收到固定座標；請確認裝置支援 XCTest location simulation。")
    }

    func testRunLocationIPC() throws {
        XCUIDevice.shared.location = XCUILocation(
            location: CLLocation(latitude: 25.0330, longitude: 121.5654)
        )

        let listener = try LocationIPCListener(port: 58432, onLocation: { location in
            XCUIDevice.shared.location = XCUILocation(location: location)
        }, onFailure: { error in
            XCTFail("Location IPC listener 啟動失敗：\(error.localizedDescription)。請停止舊的 testRunLocationIPC 後重試。")
        })
        listener.start()
        addTeardownBlock { listener.stop() }

        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Location Test Host"].waitForExistence(timeout: 10),
            "測試 App 沒有成功啟動；請確認實體 iPhone 已配對且簽章設定完成。"
        )

        let locationStatus = app.staticTexts["location-status"]
        let initialLocation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS '25.033000'"),
            object: locationStatus
        )
        XCTAssertEqual(XCTWaiter.wait(for: [initialLocation], timeout: 15), .completed)

        // Keep the listener alive while macOS sends route or joystick commands.
        let deadline = Date().addingTimeInterval(30 * 60)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: min(deadline, Date().addingTimeInterval(0.1)))
        }
    }
}
