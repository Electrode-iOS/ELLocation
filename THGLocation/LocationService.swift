//
//  LocationService.swift
//  LocationLocation
//
//  Created by Sam Grover on 3/3/15.
//  Copyright (c) 2015 Set Direction. All rights reserved.
//

import Foundation
import CoreLocation

import THGFoundation

let THGLocationErrorDomain: String = "THGLocationErrorDomain"

public enum THGLocationError: Int, NSErrorEnum {
    /// The user has denied access to location services or their device has been configured to restrict it.
    case AuthorizationDeniedOrRestricted
    /// The caller is asking for authorization 'always' but user has granted 'when in use'.
    case AuthorizationWhenInUse
    /// The caller is asking for authorization 'when in use' but user has granted 'always'.
    case AuthorizationAlways
    /// Location services are disabled.
    case LocationServicesDisabled
    
    public var domain: String {
        return "io.theholygrail.THGLocationError"
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

public enum LocationAuthorization {
    /// Authorization for location services to be used only when the app is in use by the user.
    case WhenInUse
    /// Authorization for location services to be used at all times, even when the app is not in the foreground.
    case Always
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
    - returns: An optional error that could happen when requesting authorization. See `THGLocationError`.
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
    - returns: An optional error that could happen when registering. See `THGLocationError`.
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
the protocols that define `THGLocation` services in the public API.
*/
class LocationManager: NSObject, LocationUpdateProvider, LocationAuthorizationProvider, CLLocationManagerDelegate {
    static let shared: LocationManager = LocationManager()
    
    // MARK: Properties, initializers and internal structures
    
    private var manager: CLLocationManager
    private var allLocationListeners: [LocationListener]
    private var accuracy: LocationAccuracy
    private var authorization: LocationAuthorization
    
    override init() {
        manager = CLLocationManager()
        allLocationListeners = [LocationListener]()
        accuracy = .Good
        authorization = .WhenInUse
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
        
        calculateAndUpdateAccuracy()
        startMonitoringLocation()
        
        return nil
    }
    
    func deregisterListener(listener: AnyObject) {
        if let theIndex = indexOfLocationListenerForListener(listener) {
            removeLocationListenerAtIndex(theIndex)
        }
    }
    
    // MARK: LocationAuthorizationProvider
    
    func requestAuthorization(authorization: LocationAuthorization) -> NSError? {
        if let locationServicesError = checkIfLocationServicesEnabled() {
            return locationServicesError
        }
        
        let authStatus = CLLocationManager.authorizationStatus()
        var requestAuth = false
        switch authStatus {
        case .Denied, .Restricted:
            return NSError(THGLocationError.AuthorizationDeniedOrRestricted)
        case .NotDetermined:
            requestAuth = true
        case .AuthorizedAlways:
            if authorization != .Always {
                return NSError(THGLocationError.AuthorizationAlways)
            }
        case .AuthorizedWhenInUse:
            if authorization != .WhenInUse {
                return NSError(THGLocationError.AuthorizationWhenInUse)
            }
        }
        
        if requestAuth {
            self.authorization = authorization
            switch self.authorization {
            case .Always:
                manager.requestAlwaysAuthorization()
            case .WhenInUse:
                manager.requestWhenInUseAuthorization()
            }
        }
        return nil
    }
    
    // MARK: Internal Interface
    private func startMonitoringLocation() {
        if shouldUseSignificantUpdateService() {
            manager.startMonitoringSignificantLocationChanges()
        } else {
            manager.startUpdatingLocation()
        }
    }
    
    /**
     * There are two kinds of location monitoring in iOS: significant updates and standard location monitoring.
     * Significant updates rely entirely on cell towers and therefore have low accuracy and low power consumption.
     * They also fire infrequently. If the user has requested location accuracy higher than .Coarse or wants
     * continuous updates, the significant location service is inappropriate to use. Finally, the user must have
     * requested .Always authorization status
     */
    private func shouldUseSignificantUpdateService() -> Bool {
        let hasContinuousListeners = allLocationListeners.filter({$0.request.updateFrequency == .Continuous}).count > 0
        let isAccuracyCoarseEnough = accuracy.rawValue <= LocationAccuracy.Coarse.rawValue
        return !hasContinuousListeners && isAccuracyCoarseEnough && authorization == .Always
    }

    private func checkIfLocationServicesEnabled() -> NSError? {
        if CLLocationManager.locationServicesEnabled() {
            return nil
        } else {
            return NSError(THGLocationError.LocationServicesDisabled)
        }
    }
    
    private func indexOfLocationListenerForListener(listener: AnyObject) -> Int? {
        var indexOfLocationListener: Int? = nil
        for (theIndex, aLocationListener) in self.allLocationListeners.enumerate() {
            if let actualListener: AnyObject = aLocationListener.listener {
                if actualListener === listener {
                    indexOfLocationListener = theIndex
                    break
                }
            }
        }
        return indexOfLocationListener
    }
    
    private func removeLocationListenerAtIndex(theIndex: Int) {
        synchronized(self, closure: { () -> Void in
            self.allLocationListeners.removeAtIndex(theIndex)
            if self.allLocationListeners.count == 0 {
                self.manager.stopUpdatingLocation()
                self.manager.stopMonitoringSignificantLocationChanges()
            }
        })
        
        calculateAndUpdateAccuracy()
    }
    
    private func calculateAndUpdateAccuracy() {
        var computedAccuracy: LocationAccuracy = accuracy
        
        // Map location listeners to get an array of accuracy raw values
        let accuracyRawValues = allLocationListeners.map({ (aLocationListener: LocationListener) -> Int in
            return aLocationListener.request.accuracy.rawValue
        })
        
        // Find the max in the mapped array
        if let locationAccuracy = LocationAccuracy(rawValue: accuracyRawValues.maxElement()!) {
            computedAccuracy = locationAccuracy
        }
        
        // Update if necessary
        if accuracy != computedAccuracy {
            accuracy = computedAccuracy
            
            switch accuracy {
            case .Coarse:
                manager.desiredAccuracy = kCLLocationAccuracyKilometer
            case .Good:
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            case .Better:
                manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            case .Best:
                manager.desiredAccuracy = kCLLocationAccuracyBest
            }
        }
    }
    
    private func cleanupLocationListeners(locationListenersToRemove: [LocationListener]) {
        // Run cleanup. This is currently brute force.
        synchronized(self, closure: { () -> Void in
            for aLocationListenerToRemove in locationListenersToRemove {
                var theIndexToRemove: Int? = nil
                
                for (theIndex, locationListener) in self.allLocationListeners.enumerate() {
                    if aLocationListenerToRemove === locationListener {
                        theIndexToRemove = theIndex
                        break
                    }
                }
                
                if let theIndex = theIndexToRemove {
                    self.allLocationListeners.removeAtIndex(theIndex)
                }
            }
        })
        calculateAndUpdateAccuracy()
    }
    
    // MARK: CLLocationManagerDelegate
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let mostRecentLocation = locations.last as CLLocation! {
            var locationListenersToRemove = [LocationListener]()
            
            synchronized(self, closure: { () -> Void in
                for locationListener in self.allLocationListeners {
                    if locationListener.listener != nil {
                        if locationListener.shouldUpdateListenerForLocation(mostRecentLocation) {
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                locationListener.previousCallbackLocation = mostRecentLocation
                                locationListener.request.response(success: true, location: mostRecentLocation, error: nil)
                            })
                        }
                    } else {
                        locationListenersToRemove.append(locationListener)
                    }
                }
            })
            
            cleanupLocationListeners(locationListenersToRemove)
        }
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        synchronized(self, closure: { () -> Void in
            for locationListener in self.allLocationListeners {
                if locationListener.listener != nil {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        locationListener.request.response(success: false, location: nil, error: error)
                    })
                }
            }
        })
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .Denied || status == .Restricted {
            manager.stopUpdatingLocation()
        }
        
        if status == .AuthorizedWhenInUse || status == .AuthorizedAlways {
            startMonitoringLocation()
        }
    }
}

