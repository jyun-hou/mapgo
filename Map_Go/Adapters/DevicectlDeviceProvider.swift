import Foundation

struct DevicectlDeviceProvider: DeviceProvider {
    func scan() async throws -> [DeviceSummary] {
        let output = try await DevicectlProcess.run(arguments: ["devicectl", "list", "devices", "--json-output", "-"])
        guard let data = output.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) else {
            throw LocationError.serviceFailure("devicectl 回傳格式無效。")
        }
        var devicesByID: [String: DeviceSummary] = [:]
        for record in Self.deviceRecords(in: object) where Self.isWiredConnectedIOSDevice(record) {
            if let device = Self.makeDevice(from: record) {
                devicesByID[device.id] = device
            }
        }
        return devicesByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func deviceRecords(in value: Any) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] {
            if isDeviceRecord(dictionary) { return [dictionary] }
            return dictionary.values.flatMap(deviceRecords(in:))
        }
        if let array = value as? [Any] { return array.flatMap(deviceRecords(in:)) }
        return []
    }

    private static func isDeviceRecord(_ record: [String: Any]) -> Bool {
        guard record["identifier"] is String || record["udid"] is String else { return false }
        return record["name"] != nil || record["model"] != nil || record["platformIdentifier"] != nil ||
            record["properties"] != nil || record["deviceProperties"] != nil ||
            record["hardwareProperties"] != nil || record["connectionProperties"] != nil
    }

    private static func isWiredConnectedIOSDevice(_ record: [String: Any]) -> Bool {
        let hardwareProperties = (record["hardwareProperties"] as? [String: Any]) ?? [:]
        let connectionProperties = (record["connectionProperties"] as? [String: Any]) ?? [:]
        let platform = (hardwareProperties["platform"] as? String)?.lowercased()
        let transport = (connectionProperties["transportType"] as? String)?.lowercased()
        let tunnelState = (connectionProperties["tunnelState"] as? String)?.lowercased()
        return platform == "ios" && transport == "wired" && tunnelState == "connected"
    }

    private static func makeDevice(from record: [String: Any]) -> DeviceSummary? {
        let id = (record["identifier"] as? String) ?? (record["udid"] as? String)
        guard let id else { return nil }
        let properties = (record["properties"] as? [String: Any]) ?? [:]
        let deviceProperties = (record["deviceProperties"] as? [String: Any]) ?? [:]
        let hardwareProperties = (record["hardwareProperties"] as? [String: Any]) ?? [:]
        let connectionProperties = (record["connectionProperties"] as? [String: Any]) ?? [:]
        let name = firstString(in: [record, properties, deviceProperties, hardwareProperties], keys: ["name", "deviceName", "displayName"]) ?? "iOS 裝置"
        let model = firstString(in: [record, properties, deviceProperties, hardwareProperties], keys: ["model", "marketingName", "deviceModel"])
        let hostName = firstHostName(in: connectionProperties)
        let stateText = ([record, properties, connectionProperties]
            .flatMap { dictionary in
                ["state", "connectionState", "pairingState", "tunnelState", "visibilityClass"].compactMap { dictionary[$0] as? String }
            })
            .joined(separator: " ")
            .lowercased()
        let state: DeviceConnectionState = stateText.contains("connected") ? .connected : .authorizationRequired
        return DeviceSummary(id: id, name: name, model: model, platform: .iOS, hostName: hostName, state: state)
    }

    private static func firstString(in dictionaries: [[String: Any]], keys: [String]) -> String? {
        for dictionary in dictionaries {
            for key in keys {
                if let value = dictionary[key] as? String, !value.isEmpty { return value }
            }
        }
        return nil
    }

    private static func firstHostName(in connectionProperties: [String: Any]) -> String? {
        let keys = ["localHostnames", "potentialHostnames"]
        for key in keys {
            if let hostnames = connectionProperties[key] as? [String],
               let hostname = hostnames.first(where: { $0.hasSuffix(".coredevice.local") }) {
                return hostname
            }
        }
        return nil
    }
}

private enum DevicectlProcess {
    static func run(arguments: [String]) async throws -> String {
        try Task.checkCancellation()
        let processBox = DevicectlProcessBox()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            processBox.process = process
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: LocationError.serviceFailure("無法啟動 xcrun devicectl：\(error.localizedDescription)"))
                return
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10) {
                guard processBox.beginFinish() else { return }
                process.terminate()
                continuation.resume(throwing: LocationError.serviceFailure("devicectl 掃描逾時，請確認裝置已配對且已開啟開發者模式。"))
            }
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
                guard processBox.beginFinish() else { return }
                guard process.terminationStatus == 0 else {
                    let message = String(data: error, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: LocationError.serviceFailure(message?.isEmpty == false ? message! : "devicectl 掃描失敗。"))
                    return
                }
                continuation.resume(returning: String(data: output, encoding: .utf8) ?? "")
            }
            }
        }, onCancel: {
            processBox.cancel()
        })
    }
}

private final class DevicectlProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false
    var process: Process?

    func beginFinish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return false }
        didFinish = true
        return true
    }

    func cancel() {
        lock.lock()
        let process = self.process
        lock.unlock()
        process?.terminate()
    }
}
