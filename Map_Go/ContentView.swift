//
//  ContentView.swift
//  Map_Go
//
//  Created by Jyun on 2026/10/6.
//

import SwiftUI
import MapKit
import Foundation

struct ContentView: View {
    @StateObject private var viewModel = SimulationViewModel()
    @StateObject private var userLocationManager = UserLocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic

    init() {
        let scenario = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("-UITest") }
        _viewModel = StateObject(wrappedValue: scenario.map(SimulationViewModel.init(uiTestScenario:)) ?? SimulationViewModel())
    }

    var body: some View {
        NavigationSplitView {
            deviceSidebar
                .navigationSplitViewColumnWidth(min: 230, ideal: 280)
        } detail: {
            VStack(spacing: 0) {
                mapView
                Divider()
                controls
            }
        }
        .task {
            if !ProcessInfo.processInfo.arguments.contains("-UITestConflict") {
                viewModel.scanDevices()
            }
            userLocationManager.start()
        }
        .onDisappear {
            viewModel.stopAllOperations()
            userLocationManager.stop()
        }
        .onReceive(userLocationManager.$latestLocation) { location in
            if let location { viewModel.updateUserLocation(location) }
        }
        .onReceive(userLocationManager.$errorMessage) { message in
            if let message { viewModel.errorMessage = message }
        }
        .alert("操作無法完成", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好的", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var deviceSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("連接的裝置", systemImage: "iphone.gen3")
                    .font(.headline)
                Spacer()
                Button { viewModel.scanDevices() } label: { Image(systemName: "arrow.clockwise") }
                    .help("重新掃描")
            }
            if viewModel.state == .scanning {
                ProgressView("掃描中…")
            } else if viewModel.isLoading {
                ProgressView()
            } else if viewModel.devices.isEmpty {
                ContentUnavailableView("沒有裝置", systemImage: "iphone.slash", description: Text("請連接 iPhone 或 iPad 後重新掃描。"))
            } else {
                ForEach(viewModel.devices) { device in
                    Button { viewModel.select(device: device) } label: {
                        DeviceRow(device: device, isSelected: viewModel.selectedDevice?.id == device.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            ipcConfiguration
            if let selected = viewModel.selectedDevice {
                VStack(alignment: .leading, spacing: 4) {
                    Text("目前裝置").font(.caption).foregroundStyle(.secondary)
                    Text(selected.name).font(.headline)
                    Text(viewModel.state.title).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top)
            }
        }
        .padding()
    }

    private var ipcConfiguration: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Test Runner IPC").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("iPhone IP 或主機名稱", text: $viewModel.ipcHost)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", text: $viewModel.ipcPortText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            Button("套用連線設定") { viewModel.configureIPC() }
                .font(.caption)
            Text("請先在 iPhone 執行 testRunLocationIPC，預設 Port 為 58432。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            if let current = viewModel.currentLocation {
                Marker("目前位置", coordinate: current.coordinate.clLocation).tint(.blue)
            }
            if let target = viewModel.targetLocation {
                Marker("目標", coordinate: target.clLocation).tint(.red)
            }
            if let start = viewModel.routeStartLocation, viewModel.mode == .route {
                Marker("開始", coordinate: start.clLocation).tint(.green)
            }
            if let start = viewModel.joystickStartLocation, viewModel.mode == .joystick {
                Marker("搖桿起點", coordinate: start.clLocation).tint(.orange)
            }
            if let route = viewModel.route, route.coordinates.count > 1 {
                MapPolyline(coordinates: route.coordinates.map(\.clLocation))
                    .stroke(.blue.opacity(0.7), lineWidth: 4)
            }
        }
        .overlay(alignment: .top) { searchBar }
        .onChange(of: viewModel.targetLocation) { _, target in
            if let target { cameraPosition = .region(MKCoordinateRegion(center: target.clLocation, latitudinalMeters: 1_500, longitudinalMeters: 1_500)) }
        }
        .onChange(of: viewModel.userLocation) { _, location in
            if let location, viewModel.currentLocation?.source == .initial {
                cameraPosition = .region(MKCoordinateRegion(center: location.clLocation, latitudinalMeters: 1_500, longitudinalMeters: 1_500))
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("輸入地址", text: $viewModel.addressQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit { viewModel.searchAddress() }
            Button("搜尋") { viewModel.searchAddress() }
            Divider().frame(height: 24)
            TextField("緯度", text: $viewModel.latitudeText).textFieldStyle(.roundedBorder).frame(width: 90)
            TextField("經度", text: $viewModel.longitudeText).textFieldStyle(.roundedBorder).frame(width: 90)
            Button("定位") { viewModel.setTargetFromText() }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("模式", selection: Binding(
                get: { viewModel.mode },
                set: { viewModel.setMode($0) }
            )) {
                ForEach(SimulationMode.allCases) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            HStack(alignment: .top, spacing: 24) {
                if viewModel.mode == .route { routeControls } else { joystickControls }
                Divider()
                JoystickView(isEnabled: viewModel.mode == .joystick && viewModel.selectedDevice != nil && viewModel.currentLocation != nil && viewModel.state != .routeRunning) { direction, intensity in
                    viewModel.updateJoystick(direction: direction, intensity: intensity)
                } onRelease: {
                    viewModel.endJoystick()
                }
                .frame(width: 150)
                Spacer()
            }
        }
        .padding()
    }

    private var routeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("點到點移動").font(.headline)
                Text(viewModel.state.title).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("開始")
                Text(viewModel.routeStartLocation.map(formatCoordinate) ?? "尚未設定")
                    .font(.caption).foregroundStyle(.secondary)
                Button("使用目前位置") { viewModel.useUserLocationAsStart() }
                Button("使用地圖目標") { viewModel.useTargetAsStart() }
            }
            HStack {
                Text("結束")
                Text(viewModel.routeEndLocation.map(formatCoordinate) ?? "請用搜尋或座標設定")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("速度")
                TextField("km/h", value: $viewModel.speedKmh, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.roundedBorder).frame(width: 80)
                Text("km/h（上限 60）").foregroundStyle(.secondary)
            }
            HStack {
                Button("規劃路徑") { viewModel.planRoute() }
                Button("開始") { viewModel.startRoute() }.disabled(viewModel.route == nil)
                Button("暫停") { viewModel.pauseRoute() }
                Button("停止") { viewModel.stopRoute() }
            }
            if let route = viewModel.route {
                Text("距離 \(route.distanceMeters.formatted(.number.precision(.fractionLength(0)))) m · 預估 \(route.expectedDuration.formatted(.number.precision(.fractionLength(0)))) 秒")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 460, alignment: .leading)
    }

    private var joystickControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("搖桿模式").font(.headline)
                Text(viewModel.state.title).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("起始地點")
                Text(viewModel.joystickStartLocation.map(formatCoordinate) ?? "尚未設定")
                    .font(.caption).foregroundStyle(.secondary)
                Button("使用目前位置") { viewModel.useUserLocationAsStart() }
                Button("使用地圖目標") { viewModel.useTargetAsStart() }
            }
            Text("可使用上方地址／座標輸入設定起始地點，或直接從使用者目前位置開始。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 460, alignment: .leading)
    }

    private func formatCoordinate(_ coordinate: GeoCoordinate) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}

private struct DeviceRow: View {
    let device: DeviceSummary
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: device.model?.lowercased().contains("ipad") == true ? "ipad" : "iphone").font(.title3)
            VStack(alignment: .leading) {
                Text(device.name)
                Text(device.state == .connected ? "可控制" : "需要授權")
                    .font(.caption).foregroundStyle(device.isReady ? .green : .orange)
            }
            Spacer()
            if isSelected { Image(systemName: "checkmark.circle.fill") }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct JoystickView: View {
    let isEnabled: Bool
    let onMove: (JoystickDirection, Double) -> Void
    let onRelease: () -> Void
    @State private var knobOffset: CGSize = .zero
    private let radius: CGFloat = 45

    var body: some View {
        VStack(spacing: 6) {
            Text("搖桿 · 1 Hz").font(.headline)
            ZStack {
                Circle().fill(.secondary.opacity(0.15)).frame(width: 120, height: 120)
                Circle().fill(isEnabled ? Color.accentColor : Color.gray).frame(width: 44, height: 44)
                    .offset(knobOffset)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard isEnabled else { return }
                            let x = value.translation.width
                            let y = value.translation.height
                            let length = min(sqrt(x * x + y * y), radius)
                            let scale = length == 0 ? 0 : length / max(sqrt(x * x + y * y), 1)
                            knobOffset = CGSize(width: x * scale, height: y * scale)
                            onMove(JoystickDirection(north: -y, east: x), length / radius)
                        }
                        .onEnded { _ in
                            withAnimation { knobOffset = .zero }
                            onRelease()
                        })
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
        .accessibilityIdentifier("joystick-control")
    }
}
