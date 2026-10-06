import XCTest
@testable import Map_Go

@MainActor
final class MapGoAdapterContractTests: XCTestCase {
    func testFakeGeocoderRejectsEmptyAddress() async {
        do {
            _ = try await FakeGeocoder().search(address: "   ")
            XCTFail("Expected empty address to fail")
        } catch let error as LocationError {
            XCTAssertEqual(error, .noSearchResult)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFailingRoutePlannerMapsRouteFailure() async throws {
        let start = try GeoCoordinate(latitude: 25, longitude: 121)
        let end = try GeoCoordinate(latitude: 25.001, longitude: 121.001)
        do {
            _ = try await FailingRoutePlanner().route(from: start, to: end)
            XCTFail("Expected route planning to fail")
        } catch let error as LocationError {
            XCTAssertEqual(error, .routeUnavailable)
        }
    }

    func testDisconnectedControllerReturnsFailure() async throws {
        let coordinate = try GeoCoordinate(latitude: 25, longitude: 121)
        let device = DeviceSummary(id: "test", name: "Test iPhone", model: "iPhone", platform: .iOS, hostName: nil, state: .connected)
        do {
            try await FailingLocationController().send(location: coordinate, to: device)
            XCTFail("Expected disconnected controller to fail")
        } catch let error as LocationError {
            XCTAssertEqual(error, .serviceFailure("Fake 裝置已斷線。"))
        }
    }

    func testFakeServiceHonorsCancellation() async {
        let task = Task {
            try await Task.sleep(for: .seconds(10))
            return true
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected the fake service operation to be cancelled")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
