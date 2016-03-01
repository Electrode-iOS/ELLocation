//
//  LocationService.swift
//  LocationLocation
//
//  Created by Sam Grover on 3/3/15.
//  Copyright (c) 2015 WalmartLabs. All rights reserved.
//

import Foundation
import CoreLocation

import ELFoundation

let ELLocationErrorDomain: String = "ELLocationErrorDomain"

public enum ELLocationError: Int, NSErrorEnum {
    /// The user has denied access to location services or their device has been configured to restrict it.
    case AuthorizationDeniedOrRestricted
    /// The caller is asking for authorization 'always' but user has granted 'when in use'.
    case AuthorizationWhenInUse
    /// The caller is asking for authorization 'when in use' but user has granted 'always'.
    case AuthorizationAlways
    /// Location services are disabled.
    case LocationServicesDisabled
    
    public var domain: String {
        return "io.theholygrail.ELLocationError"
    }
    
    public var errorDescription: String {
        switch self {
        case .AuthorizationDeniedOrRestricted:
            return "The user has denied location services in Settings or has been restricted from using them."
        case .AuthorizationWhenInUse:
            return "The user has granted permission to location services only when the app is in use."
        case .AuthorizationAlways:
            return "The user has granted permission to location services always, so use that or change it."
        case .LocationServicesDisabled:
            return "Location services are not enabled."
        }
    }
}

/**
More time and power is used going down this list as the system tries to provide a more accurate location,
so be conservative according to your needs. `Good` should work well for most cases.
*/
public enum LocationAccuracy: Int {
    case Coarse
    case Good
    case Better
    case Best
}

private func < (lhs: LocationAccuracy, rhs: LocationAccuracy) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

/**
Callback frequency setting. Lowest power consumption is achieved by combining LocationUpdateFrequency.ChangesOnly
 with LocationAccuracy.Coarse

- ChangesOnly: Notify listeners only when location changes. The granularity of this depends on the LocationAccuracy setting
- Continuous:  Notify listeners at regular, frequent intervals (~1-2s)
*/
public enum LocationUpdateFrequency: Int {
    case ChangesOnly
    case Continuous
}

private func < (lhs: LocationUpdateFrequency, rhs: LocationUpdateFrequency) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

public enum LocationAuthorization {
    /// Authorization for location services to be used only when the app is in use by the user.
    case WhenInUse
    /// Authorization for location services to be used at all times, even when the app is not in the foreground.
    case Always
}

/**
 There are two kinds of location monitoring in iOS: significant updates and standard location monitoring.
 Significant updates are more power efficient, but have limitations on accuracy and update frequency.
 */
private enum LocationMonitoring {
    /// Monitor for only "significant updates" to the user's location (using cell towers only)
    case SignificantUpdates
    /// Monitor for all updates to the user's location (using GPS, WiFi, etc)
    case Standard
}

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
}

// MARK: Location Authorization API

// An internal protocol for a type that wants to provide location authorization.
public protocol LocationAuthorizationProvider {
    func requestAuthorization(authorization: LocationAuthorization) -> NSError?
}

// The interface for requesting location authorization
public struct LocationAuthorizationService: LocationAuthorizationProvider {
    let locationAuthorizationProvider: LocationAuthorizationProvider = LocationManager.shared
    
    /**
    Request the specified authorization.
    
    - parameter authorization: The authorization being requested.
    - returns: An optional error that could happen when requesting authorization. See `ELLocationError`.
    */
    public func requestAuthorization(authorization: LocationAuthorization) -> NSError? {
        return locationAuthorizationProvider.requestAuthorization(authorization)
    }
    
    public init() {}
}

// MARK: Location Listener API

/**
This handler is called when a location is updated or if there is an error.

- parameter success: `true` if an updated location is available. `false` if there was an error.
- parameter location: The location if `success` is `true`. `nil` otherwise.
- parameter error: The error if `success` is `false`. `nil` otherwise.
*/
public typealias LocationUpdateResponseHandler = (success: Bool, location: CLLocation?, error: NSError?) -> Void

public struct LocationUpdateRequest {
    let accuracy: LocationAccuracy
    let updateFrequency: LocationUpdateFrequency
    let response: LocationUpdateResponseHandler
    
    /**
    Convenience initializer defaulting updateFrequency to .Continuous
    */
    public init(accuracy: LocationAccuracy, response: LocationUpdateResponseHandler) {
        self.init(accuracy: accuracy, updateFrequency: .Continuous, response: response)
    }
    
    /**
    Initializes a request to be used for registering for location updates.
    
    - parameter accuracy: The accuracy desired by the listener. Since there can be multiple listeners, the framework endeavors to provide the highest level of accuracy registered.
    - parameter updateFrequency: The rate at which to notify the listener
    - parameter response: This closure is called when a update is received or if there's an error.
    */
    public init(accuracy: LocationAccuracy, updateFrequency: LocationUpdateFrequency, response: LocationUpdateResponseHandler) {
        self.accuracy = accuracy
        self.response = response
        self.updateFrequency = updateFrequency
    }
}

// A protocol for a type that wants to provide location updates.
public protocol LocationUpdateProvider {
    func registerListener(listener: AnyObject, request: LocationUpdateRequest) -> NSError?
    func deregisterListener(listener: AnyObject)
}

// The interface for requesting location updates. Listeners can register to be informed of location updates
// They can request to be deregistered or will be deregistered automatically when they are dealloced.
public struct LocationUpdateService: LocationUpdateProvider {
    let locationProvider: LocationUpdateProvider = LocationManager.shared
    
    /**
    Registers a listener to receive location updates as per the parameters defined in the request.
    
    - parameter listener: The listener to register.
    - parameter request: The parameters of the request.
    - returns: An optional error that could happen when registering. See `ELLocationError`.
    */
    public func registerListener(listener: AnyObject, request: LocationUpdateRequest) -> NSError? {
        return locationProvider.registerListener(listener, request: request)
    }
    
    /**
    Deregisters a listener from receiving any more location updates.
    
    - parameter listener: The listener to deregister.
    */
    public func deregisterListener(listener: AnyObject) {
        locationProvider.deregisterListener(listener)
    }
    
    public init() {}
}

// MARK: Internal location manager class

/**
This is the internal class that is set up as a singleton that interfaces with `CLLocationManager` and adopts
the protocols that define `ELLocation` services in the public API.
*/
class LocationManager: NSObject, LocationUpdateProvider, LocationAuthorizationProvider, CLLocationManagerDelegate {
    static let shared: LocationManager = LocationManager()
    
    // MARK: Properties, initializers and internal structures
    
    var manager: CLLocationManager
    private var allLocationListeners: [LocationListener]

    /// The current Core Location authorization status
    private var authorizationStatus: CLAuthorizationStatus {
        return CLLocationManager.authorizationStatus()
    }

    /// The accuracy, based on the current set of listener requests.
    private var accuracy: LocationAccuracy {
        let allAccuracies = allLocationListeners.map({ $0.request.accuracy })

        guard let value = allAccuracies.maxElement(<) else {
            return .Good
        }

        return value
    }

    /// The update frequency, based on the current set of listener requests.
    private var updateFrequency: LocationUpdateFrequency {
        let allUpdateFrequencies = allLocationListeners.map({ $0.request.updateFrequency })

        guard let value = allUpdateFrequencies.maxElement(<) else {
            return .ChangesOnly
        }

        return value
    }

    /// The monitoring mode for the current state.
    private var monitoring: LocationMonitoring? {
        guard !allLocationListeners.isEmpty else {
            return nil
        }

        if authorizationStatus.requiresStandardMonitoring {
            return .Standard
        }

        if accuracy.requiresStandardMonitoring {
            return .Standard
        }

        if updateFrequency.requiresStandardMonitoring {
            return .Standard
        }

        return .SignificantUpdates
    }

    /// The underlying location manager's desired accuracy for the current state.
    private var coreLocationDesiredAccuracy: CLLocationAccuracy {
        switch accuracy {
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

    /// The underlying location manager's desired distance filter for the current state.
    private var coreLocationDistanceFilter: CLLocationDistance {
        // NOTE: A distance filter of half the accuracy allows some updates while the device is
        //       stationary (caused by GPS fluctuations) in an attempt to ensure timely updates
        //       while the device is moving (so previous inaccuracies can be corrected).
        switch accuracy {
        case .Best:
            // Two meters is good for best accuracy, which evaluates to -1.0 but typically generates
            // updates with an accuracy of ±5m in practice.
            return 2.0
        default:
            return coreLocationDesiredAccuracy / 2
        }
    }

    override init() {
        manager = CLLocationManager()
        allLocationListeners = [LocationListener]()
        super.init()
        manager.delegate = self
    }
    
    class LocationListener {
        static let locationChangeThresholdMeters: [LocationAccuracy: CLLocationDistance] = [
            .Best: 0,
            .Better: 10,
            .Good: 100,
            .Coarse: 200
        ]
        
        weak var listener: AnyObject?
        var request: LocationUpdateRequest
        var previousCallbackLocation: CLLocation?

        init(listener: AnyObject, request: LocationUpdateRequest) {
            self.listener = listener
            self.request = request
        }
        
        func shouldUpdateListenerForLocation(location: CLLocation) -> Bool {
            switch request.updateFrequency {
            case .Continuous:
                return true
            case .ChangesOnly:
                if previousCallbackLocation == nil || previousCallbackLocation?.distanceFromLocation(location) >= LocationListener.locationChangeThresholdMeters[request.accuracy] {
                    return true
                }
                return false
            }
        }
    }
    
    // MARK: LocationUpdateProvider
    
    func registerListener(listener: AnyObject, request: LocationUpdateRequest) -> NSError? {
        if let locationServicesError = checkIfLocationServicesEnabled() {
            return locationServicesError
        }
        
        let locationListener = LocationListener(listener: listener, request: request)
        
        synchronized(self, closure: { () -> Void in
            self.allLocationListeners.append(locationListener)
        })

        updateLocationMonitoring()

        return nil
    }
    
    func deregisterListener(listener: AnyObject) {
        synchronized(self) {
            for (index, locationListener) in self.allLocationListeners.enumerate() {
                if locationListener.listener === listener {
                    self.allLocationListeners.removeAtIndex(index)
                    break
                }
            }
        }

        updateLocationMonitoring()
    }
    
    // MARK: LocationAuthorizationProvider
    
    func requestAuthorization(authorization: LocationAuthorization) -> NSError? {
        if let locationServicesError = checkIfLocationServicesEnabled() {
            return locationServicesError
        }

        var requestAuth = false

        switch authorizationStatus {
        case .Denied, .Restricted:
            return NSError(ELLocationError.AuthorizationDeniedOrRestricted)
        case .NotDetermined:
            requestAuth = true
        case .AuthorizedAlways:
            if authorization != .Always {
                return NSError(ELLocationError.AuthorizationAlways)
            }
        case .AuthorizedWhenInUse:
            if authorization != .WhenInUse {
                return NSError(ELLocationError.AuthorizationWhenInUse)
            }
        }
        
        if requestAuth {
            switch authorization {
            case .Always:
                manager.requestAlwaysAuthorization()
            case .WhenInUse:
                manager.requestWhenInUseAuthorization()
            }
        }

        return nil
    }
    
    // MARK: Internal Interface

    private func updateLocationMonitoring() {
        synchronized(self) {
            let manager = self.manager

            manager.desiredAccuracy = self.coreLocationDesiredAccuracy

            // Use a distance filter to ignore unnecessary updates so the app can sleep more often
            manager.distanceFilter = self.coreLocationDistanceFilter

            if let monitoring = self.monitoring {
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

    private func checkIfLocationServicesEnabled() -> NSError? {
        if CLLocationManager.locationServicesEnabled() {
            return nil
        } else {
            return NSError(ELLocationError.LocationServicesDisabled)
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
                // FIXME: previousCallbackLocation is assigned in the async block, but it is
                // used in shouleUpdateListener() which creates a race condition.
                if locationListener.shouldUpdateListenerForLocation(mostRecentLocation) {
                    // Is it weird that the `response` handler can still receive callbacks even after the listener
                    // has been unregistered? I think that could happen with this design.
                    dispatch_async(dispatch_get_main_queue(), {
                        locationListener.previousCallbackLocation = mostRecentLocation
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
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
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
