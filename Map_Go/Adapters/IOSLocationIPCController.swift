import Foundation
import Network

struct LocationIPCCommand: Codable, Sendable {
    let type: String
    let requestID: UUID
    let latitude: Double
    let longitude: Double

    static func setLocation(_ coordinate: GeoCoordinate) -> LocationIPCCommand {
        LocationIPCCommand(type: "setLocation", requestID: UUID(), latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

struct LocationIPCResponse: Codable, Sendable {
    let requestID: UUID
    let success: Bool
    let message: String?
}

actor IOSLocationIPCController: LocationController {
    private var host: String?
    private var port: UInt16 = 58432

    func configure(host: String, port: UInt16) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.port = port
    }

    func send(location: GeoCoordinate, to device: DeviceSummary) async throws {
        guard device.isReady else { throw LocationError.deviceUnavailable }
        guard let host, !host.isEmpty, let port = NWEndpoint.Port(rawValue: port) else {
            throw LocationError.serviceFailure("請先設定 Test Runner 的 IP 位址與 Port。")
        }

        let command = LocationIPCCommand.setLocation(location)
#if DEBUG
        print("[MapGo IPC] send location: \(location.latitude), \(location.longitude) to \(host):\(port)")
#endif
        let data = try JSONEncoder().encode(command) + Data([0x0A])
        let responseData = try await send(data: data, host: host, port: port)
        let response = try JSONDecoder().decode(LocationIPCResponse.self, from: responseData)
        guard response.success else {
            throw LocationError.serviceFailure(response.message ?? "Test Runner 拒絕定位命令。")
        }
    }

    private func send(data: Data, host: String, port: NWEndpoint.Port) async throws -> Data {
        let connectionBox = IPCConnectionBox()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
            let queue = DispatchQueue(label: "com.mapgo.location-ipc")
            connectionBox.connection = connection

            func finish(_ result: Result<Data, Error>) {
                guard connectionBox.beginFinish() else { return }
                connection.cancel()
                continuation.resume(with: result)
            }

            connection.stateUpdateHandler = { state in
#if DEBUG
                print("[MapGo IPC] connection state: \(state)")
#endif
                switch state {
                case .waiting(let error), .failed(let error):
                    finish(.failure(error))
                case .ready:
                    break
                case .cancelled:
                    finish(.failure(LocationError.cancelled))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 5) {
                finish(.failure(LocationError.serviceFailure("無法在 5 秒內連線到 iPhone Test Runner。")))
            }
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    finish(.failure(error))
                    return
                }
                Self.receiveResponse(on: connection, buffer: Data(), finish: finish)
            })
            }
        }, onCancel: {
            connectionBox.cancel()
        })
    }

    private static func receiveResponse(
        on connection: NWConnection,
        buffer: Data,
        finish: @escaping (Result<Data, Error>) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { content, _, isComplete, error in
            if let error {
                finish(.failure(error))
                return
            }

            let received = buffer + (content ?? Data())
            if let newline = received.firstIndex(of: 0x0A) {
                finish(.success(received[..<newline]))
            } else if isComplete {
                finish(.success(received))
            } else {
                Self.receiveResponse(on: connection, buffer: received, finish: finish)
            }
        }
    }
}

private final class IPCConnectionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false
    var connection: NWConnection?

    func beginFinish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return false }
        didFinish = true
        return true
    }

    func cancel() {
        lock.lock()
        let connection = self.connection
        lock.unlock()
        connection?.cancel()
    }
}
