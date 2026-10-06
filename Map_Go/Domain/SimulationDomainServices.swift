import CoreLocation

enum RouteSampler {
    static func coordinate(
        on route: RoutePath,
        elapsed: TimeInterval,
        speedMetersPerSecond: Double
    ) throws -> GeoCoordinate {
        guard !route.coordinates.isEmpty, speedMetersPerSecond > 0 else {
            throw LocationError.routeUnavailable
        }
        guard route.coordinates.count > 1 else { return route.coordinates[0] }

        let segmentDistances = zip(route.coordinates, route.coordinates.dropFirst()).map { start, end in
            CLLocation(latitude: start.latitude, longitude: start.longitude)
                .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        }
        let totalDistance = segmentDistances.reduce(0, +)
        guard totalDistance > 0 else { return route.coordinates[0] }

        let distance = min(max(elapsed, 0) * speedMetersPerSecond, totalDistance)
        var accumulated = 0.0
        for index in segmentDistances.indices {
            let segmentDistance = segmentDistances[index]
            if accumulated + segmentDistance >= distance {
                let progress = segmentDistance == 0 ? 0 : (distance - accumulated) / segmentDistance
                let start = route.coordinates[index]
                let end = route.coordinates[index + 1]
                return try GeoCoordinate(
                    latitude: start.latitude + (end.latitude - start.latitude) * progress,
                    longitude: start.longitude + (end.longitude - start.longitude) * progress
                )
            }
            accumulated += segmentDistance
        }
        return route.coordinates[route.coordinates.count - 1]
    }
}
