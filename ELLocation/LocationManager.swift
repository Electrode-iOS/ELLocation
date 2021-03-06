//
//  LocationManager.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

import ELFoundation
import CoreLocation

let NSLocationAlwaysUsageDescriptionKey = "NSLocationAlwaysUsageDescription"
let NSLocationWhenInUseUsageDescriptionKey = "NSLocationWhenInUseUsageDescription"

private extension LocationAccuracy {
    /**
     Whether acheiving this accuracy value requires standard monitoring.

     Significant updates relies on entirely on cell towers and therefore have low accuracy. They are
     only suitable for Coarse accuracy.
     */
    var requiresStandardMonitoring: Bool {
        switch self {
        case .Good, .Better, .Best:
            return true
        default:
            return false
        }
    }
}

private extension LocationUpdateFrequency {
    /**
     Whether acheiving this update frequency value requires standard monitoring.

     Significant updates fire infrequently (if at all). Then are not suitable for continuous updates.
     */
    var requiresStandardMonitoring: Bool {
        switch self {
        case .Continuous:
            return true
        default:
            return false
        }
    }
}

private extension CLAuthorizationStatus {
    /**
     Whether this authorization status requires standard monitoring.

     Significant updates require authorization to access the user's location when the app is not in
     use (i.e. "Always" authorization).

     TODO: Is this true?
     */
    var requiresStandardMonitoring: Bool {
        switch self {
        case .AuthorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    /**
     Whether this authorization status allows any form of monitoring.
     */
    var allowsMonitoring: Bool {
        switch self {
        case .NotDetermined, .Denied, .Restricted:
            return false
        default:
            return true
        }
    }
}

/**
 A custom protocol to break the tight coupling of `LocationManager` and `CLLocationManager`.

 Note: Creating instance properties for `coreLocationServicesEnabled` and `coreLocationAuthorizationStatus`
 allows them to be mocked more easily.
 */
protocol ELCLLocationManager: AnyObject {
    /// A cover method for `CLLocationManager.locationServicesEnabled()`
    var coreLocationServicesEnabled: Bool { get }
    /// A cover method for `CLLocationManager.authorizationStatus()`
    var coreLocationAuthorizationStatus: CLAuthorizationStatus { get }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    weak var delegate: CLLocationManagerDelegate? { get set }

    func requestAlwaysAuthorization()
    var alwaysUsageDescription: String? { get }

    func requestWhenInUseAuthorization()
    var whenInUseUsageDescription: String? { get }

    func startUpdatingLocation()
    func stopUpdatingLocation()
    func startMonitoringSignificantLocationChanges()
    func stopMonitoringSignificantLocationChanges()
}

extension CLLocationManager: ELCLLocationManager {
    var coreLocationServicesEnabled: Bool {
        return CLLocationManager.locationServicesEnabled()
    }

    var coreLocationAuthorizationStatus: CLAuthorizationStatus {
        return CLLocationManager.authorizationStatus()
    }

    var alwaysUsageDescription: String? {
        return NSBundle.mainBundle().infoDictionary?[NSLocationAlwaysUsageDescriptionKey] as? String
    }

    var whenInUseUsageDescription: String? {
        return NSBundle.mainBundle().infoDictionary?[NSLocationWhenInUseUsageDescriptionKey] as? String
    }
}

/**
 This is the internal class that is set up as a singleton that interfaces with `CLLocationManager` and adopts
 the protocols that define `ELLocation` services in the public API.
 */
class LocationManager: NSObject, LocationUpdateProvider, LocationAuthorizationProvider, CLLocationManagerDelegate {
    /// A shared singleton instance for internal use.
    static let shared: LocationManager = LocationManager()

    // MARK: Properties, initializers and internal structures

    private var manager: ELCLLocationManager
    private var allLocationListeners: [LocationListener]

    /// The current Core Location authorization status
    private var authorizationStatus: CLAuthorizationStatus {
        return manager.coreLocationAuthorizationStatus
    }

    /// The monitoring mode for the current state.
    ///
    /// This takes into account the listeners' monitoring modes and the authorization status.
    private var monitoringMode: LocationMonitoring? {
        guard authorizationStatus.allowsMonitoring else {
            return nil
        }

        guard let value = allLocationListeners.map({ $0.monitoringMode }).maxElement() else {
            return nil
        }

        if authorizationStatus.requiresStandardMonitoring {
            return .Standard
        }

        return value
    }

    /// The desired accuracy for the current state.
    private var desiredAccuracy: CLLocationAccuracy {
        // Note: CLLocationAccuracy is expressed as an allowable amount of error, so we want the "minimum" value.

        guard let value = allLocationListeners.map({ $0.desiredAccuracy }).minElement() else {
            return kCLLocationAccuracyHundredMeters
        }

        return value
    }

    /// The distance filter for the current state.
    private var distanceFilter: CLLocationDistance {
        guard let value = allLocationListeners.map({ $0.distanceFilter }).minElement() else {
            return kCLDistanceFilterNone
        }

        return value
    }

    override convenience init() {
        self.init(manager: CLLocationManager())
    }

    init(manager: ELCLLocationManager) {
        self.manager = manager
        self.allLocationListeners = [LocationListener]()
        super.init()
        manager.delegate = self
    }

    private class LocationListener {
        weak var listener: AnyObject?
        var request: LocationUpdateRequest
        var previousCallbackLocation: CLLocation?

        init(listener: AnyObject, request: LocationUpdateRequest) {
            self.listener = listener
            self.request = request
        }

        /// The monitoring mode for this listener
        var monitoringMode: LocationMonitoring {
            if request.accuracy.requiresStandardMonitoring {
                return .Standard
            }

            if request.updateFrequency.requiresStandardMonitoring {
                return .Standard
            }

            return .SignificantUpdates
        }

        /// The desired accuracy for this listener
        var desiredAccuracy: CLLocationAccuracy {
            switch request.accuracy {
            case .Coarse:
                return kCLLocationAccuracyKilometer
            case .Good:
                return kCLLocationAccuracyHundredMeters
            case .Better:
                return kCLLocationAccuracyNearestTenMeters
            case .Best:
                return kCLLocationAccuracyBest
            }
        }

        /// The distance filter for this listener
        var distanceFilter: CLLocationDistance {
            guard request.updateFrequency != .Continuous else {
                return kCLDistanceFilterNone
            }

            // NOTE: A distance filter of half the accuracy allows some updates while the device is
            //       stationary (caused by GPS fluctuations) in an attempt to ensure timely updates
            //       while the device is moving (so previous inaccuracies can be corrected).
            switch request.accuracy {
            case .Best:
                // Two meters is good for best accuracy, which evaluates to -1.0 but typically generates
                // updates with an accuracy of ±5m in practice.
                return 2.0
            default:
                return desiredAccuracy / 2
            }
        }

        func shouldUpdateListenerForLocation(currentLocation: CLLocation) -> Bool {
            guard let previousLocation = previousCallbackLocation else {
                return true
            }

            let distance = previousLocation.distanceFromLocation(currentLocation)

            return distance >= distanceFilter
        }
    }

    // MARK: LocationUpdateProvider

    func registerListener(listener: AnyObject, request: LocationUpdateRequest) throws {
        guard manager.coreLocationServicesEnabled else {
            throw ELLocationError.LocationServicesDisabled
        }

        let locationListener = LocationListener(listener: listener, request: request)

        synchronized(self) {
            unsafeRemoveListener(listener)

            allLocationListeners.append(locationListener)
        }

        updateLocationMonitoring()
    }

    func deregisterListener(listener: AnyObject) {
        synchronized(self) {
            unsafeRemoveListener(listener)
        }

        updateLocationMonitoring()
    }

    /**
     Removes the (only) entry for listener from `allLocationListeners`, if one exists.

     **This method is not threadsafe.** It may only safely be called from inside a `synchronized(self)` block.
     */
    private func unsafeRemoveListener(listener: AnyObject) {
        let locationListeners = allLocationListeners

        for (index, locationListener) in locationListeners.enumerate() {
            if locationListener.listener === listener {
                allLocationListeners.removeAtIndex(index)
                break
            }
        }
    }

    // MARK: LocationAuthorizationProvider

    func requestAuthorization(authorization: LocationAuthorization) throws {
        guard manager.coreLocationServicesEnabled else {
            throw ELLocationError.LocationServicesDisabled
        }

        // Note: According to Apple's documentation, requesting authorization *only* works if the current status
        // is not determined. In practice, that is not entirely true. If When-In-Use authorization was previously
        // requested--and granted--the app may still request Always authorization (once). However, if the user
        // choses not to allow When-In-Use authorization, or manually changes location authorization to "never"
        // in their Settings, then the app loses this ability to request Always authorization.
        //
        // Example 1:
        //
        // 1. App requests `.WhenInUse` authorization.
        // 2. iOS shows "Allow Access When in Use" alert.
        // 3. User taps "Allow".
        // 4. App requests `.Always` authorization.
        // 5. iOS shows "Allow Access Always" alert.
        //
        // Example 2:
        //
        // 1. App requests `.WhenInUse` authorization.
        // 2. iOS shows "Allow Access When in Use" alert.
        // 3. User taps "Allow".
        // 4. User opens Settings and changes location access to "Never".
        // 5. App requests `.Always` authorization.
        // 6. **Nothing happens**
        //
        // Example 3:
        //
        // 1. App requests `.WhenInUse` authorization.
        // 2. iOS shows "Allow Access When in Use" alert.
        // 3. User taps "Don't Allow".
        // 4. App requests `.Always` authorization.
        // 5. **Nothing happens**
        //
        // Because of how finicky this is, and that it goes contrary to the documentation, this code returns an
        // error if "always" authorization is requested and the current authorization status is "when in use".

        switch (authorizationStatus, authorization) {

        case (.Denied, _):
            throw ELLocationError.AuthorizationDenied

        case (.Restricted, _):
            throw ELLocationError.AuthorizationRestricted

        case (.AuthorizedWhenInUse, .Always):
            throw ELLocationError.AuthorizationWhenInUse

        case (.NotDetermined, .WhenInUse):
            if manager.whenInUseUsageDescription == nil {
                throw ELLocationError.UsageDescriptionMissing
            }
            manager.requestWhenInUseAuthorization()

        case (.NotDetermined, .Always):
            if manager.alwaysUsageDescription == nil {
                throw ELLocationError.UsageDescriptionMissing
            }
            manager.requestAlwaysAuthorization()

        default:
            // We already have the desired authorization (or higher).
            break
        }
    }

    // MARK: Internal Interface

    private func updateLocationMonitoring() {
        synchronized(self) {
            let manager = self.manager

            manager.desiredAccuracy = self.desiredAccuracy

            // Use a distance filter to ignore unnecessary updates so the app can sleep more often
            manager.distanceFilter = self.distanceFilter

            if let monitoring = self.monitoringMode {
                switch monitoring {
                case .SignificantUpdates:
                    manager.startMonitoringSignificantLocationChanges()
                    manager.stopUpdatingLocation()
                case .Standard:
                    manager.startUpdatingLocation()
                    manager.stopMonitoringSignificantLocationChanges()
                }
            } else {
                manager.stopUpdatingLocation()
                manager.stopMonitoringSignificantLocationChanges()
            }
        }
    }

    /// Searches for listeners that have been deallocated and removes them from the list.
    private func cleanUpLocationListeners() {
        var foundZombies = false

        synchronized(self) {
            let locationListeners = self.allLocationListeners

            for (index, locationListener) in locationListeners.enumerate() where locationListener.listener == nil {
                self.allLocationListeners.removeAtIndex(index)
                foundZombies = true
            }
        }

        if foundZombies {
            updateLocationMonitoring()
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let mostRecentLocation = locations.last as CLLocation! else {
            return
        }

        synchronized(self) {
            let locationListeners = self.allLocationListeners

            for locationListener in locationListeners where locationListener.listener != nil {
                if locationListener.shouldUpdateListenerForLocation(mostRecentLocation) {
                    locationListener.previousCallbackLocation = mostRecentLocation

                    // Is it weird that the `response` handler can still receive callbacks even after the listener
                    // has been unregistered? I think that could happen with this design.
                    dispatch_async(dispatch_get_main_queue(), {
                        locationListener.request.response(success: true, location: mostRecentLocation, error: nil)
                    })
                }
            }
        }

        cleanUpLocationListeners()
    }

    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        synchronized(self) {
            let locationListeners = self.allLocationListeners

            for locationListener in locationListeners where locationListener.listener != nil {
                dispatch_async(dispatch_get_main_queue(), {
                    locationListener.request.response(success: false, location: nil, error: error)
                })
            }
        }
        
        cleanUpLocationListeners()
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        updateLocationMonitoring()
    }
}
