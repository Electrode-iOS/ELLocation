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

public enum THGLocationErrorCode: Int {
    case AuthorizationDeniedOrRestricted
    case AuthorizationChanged
    case LocationServicesDisabled
}

public enum LocationAccuracy: Int {
    // More time and power is used going down this list as the system tries to provide a more accurate location,
    // so be conservative according to your needs. Good should work well for most cases.
    case Good
    case Better
    case Best
}

public enum LocationAuthorization {
    case WhenInUse
    case Always
}

// MARK: Location Authorization API

protocol LocationAuthorizationProvider {
    func requestAuthorization(authorization: LocationAuthorization) -> NSError?
}

public struct LocationAuthorizationService {
    let locationAuthorizationProvider: LocationAuthorizationProvider = LocationManager.shared
    
    public func requestAuthorization(authorization: LocationAuthorization) -> NSError? {
        return locationAuthorizationProvider.requestAuthorization(authorization)
    }
    
    public init() {}
}

// MARK: Location Listener API

public typealias LocationUpdateResponseHandler = (Bool, CLLocation?, NSError?) -> Void

public struct LocationUpdateRequest {
    let accuracy: LocationAccuracy
    let response: LocationUpdateResponseHandler
    
    public init(accuracy: LocationAccuracy, response: LocationUpdateResponseHandler) {
        self.accuracy = accuracy
        self.response = response
    }
}

protocol LocationUpdateProvider {
    func addListener(listener: AnyObject, request: LocationUpdateRequest) -> NSError?
    func removeListener(listener: AnyObject)
}

public struct LocationUpdateService {
    let locationProvider: LocationUpdateProvider = LocationManager.shared
    
    public func addListener(listener: AnyObject, request: LocationUpdateRequest) -> NSError? {
        return locationProvider.addListener(listener, request: request)
    }
    
    public func removeListener(listener: AnyObject) {
        locationProvider.removeListener(listener)
    }
    
    public init() {}
}

// MARK: Internal central manager class

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
        weak var listener: AnyObject?
        var request: LocationUpdateRequest
        
        init(listener: AnyObject, request: LocationUpdateRequest) {
            self.listener = listener
            self.request = request
        }
    }
    
    // MARK: LocationUpdateProvider
    
    func addListener(listener: AnyObject, request: LocationUpdateRequest) -> NSError? {
        if let locationServicesError = checkIfLocationServicesEnabled() {
            return locationServicesError
        }
        
        let locationListener = LocationListener(listener: listener, request: request)
        
        synchronized(self, { () -> Void in
            self.allLocationListeners.append(locationListener)
        })
        
        calculateAndUpdateAccuracy()
        manager.startUpdatingLocation()
        return nil
    }
    
    func removeListener(listener: AnyObject) {
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
            return NSError(
                domain: THGLocationErrorDomain,
                code: THGLocationErrorCode.AuthorizationDeniedOrRestricted.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "The user has denied location services in Settings or has been restricted from using them."]
            )
        case .NotDetermined:
            requestAuth = true
        case .AuthorizedAlways:
            if authorization != .Always {
                return NSError(
                    domain: THGLocationErrorDomain,
                    code: THGLocationErrorCode.AuthorizationChanged.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "The user has granted permission to location services only when the app is in use."]
                )
            }
        case .AuthorizedWhenInUse:
            if authorization != .WhenInUse {
                return NSError(
                    domain: THGLocationErrorDomain,
                    code: THGLocationErrorCode.AuthorizationChanged.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "The user has granted permission to location services always, so use that."]
                )
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
    
    private func checkIfLocationServicesEnabled() -> NSError? {
        if CLLocationManager.locationServicesEnabled() {
            return nil
        } else {
            return NSError(
                domain: THGLocationErrorDomain,
                code: THGLocationErrorCode.LocationServicesDisabled.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Location services are not enabled."]
            )
        }
    }
    
    private func indexOfLocationListenerForListener(listener: AnyObject) -> Int? {
        var indexOfLocationListener: Int? = nil
        for (theIndex, aLocationListener) in enumerate(self.allLocationListeners) {
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
        synchronized(self, { () -> Void in
            self.allLocationListeners.removeAtIndex(theIndex)
        })
        
        calculateAndUpdateAccuracy()
    }
    
    private func calculateAndUpdateAccuracy() {
        var computedAccuracy: LocationAccuracy = accuracy
        
        // Map location listeners to get an array of accuracy raw values
        var accuracyRawValues = map(allLocationListeners, { (aLocationListener: LocationListener) -> Int in
            return aLocationListener.request.accuracy.rawValue
        })
        
        // Find the max in the mapped array
        if let locationAccuracy = LocationAccuracy(rawValue: maxElement(accuracyRawValues)) {
            computedAccuracy = locationAccuracy
        }
        
        // Update if necessary
        if accuracy != computedAccuracy {
            accuracy = computedAccuracy
            
            switch accuracy {
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
        synchronized(self, { () -> Void in
            for aLocationListenerToRemove in locationListenersToRemove {
                var theIndexToRemove: Int? = nil
                
                for (theIndex, locationListener) in enumerate(self.allLocationListeners) {
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
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        if let mostRecentLocation = locations.last as? CLLocation {
            var locationListenersToRemove = [LocationListener]()
            
            synchronized(self, { () -> Void in
                for locationListener in self.allLocationListeners {
                    if locationListener.listener != nil {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            locationListener.request.response(true, mostRecentLocation, nil)
                        })
                    } else {
                        locationListenersToRemove.append(locationListener)
                    }
                }
            })
            
            cleanupLocationListeners(locationListenersToRemove)
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        if let theError = error {
            synchronized(self, { () -> Void in
                for locationListener in self.allLocationListeners {
                    if locationListener.listener != nil {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            locationListener.request.response(false, nil, theError)
                        })
                    }
                }
            })
        }
    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .Denied || status == .Restricted {
            manager.stopUpdatingLocation()
        }
        
        if status == .AuthorizedWhenInUse || status == .AuthorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

