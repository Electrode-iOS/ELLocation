//
//  LocationUpdateService.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

// A protocol for a type that wants to provide location updates.
public protocol LocationUpdateProvider {
    func registerListener(listener: AnyObject, request: LocationUpdateRequest) throws
    func deregisterListener(listener: AnyObject)
}

// The interface for requesting location updates. Listeners can register to be informed of location updates
// They can request to be deregistered or will be deregistered automatically when they are dealloced.
public struct LocationUpdateService: LocationUpdateProvider {
    let locationProvider: LocationUpdateProvider

    /**
     Registers a listener to receive location updates as per the parameters defined in the request.
     
     A listener may only be registered with one request at a time. If a listener is registered more than once,
     previously-registered requests will be discarded.

     - parameter listener: The listener to register.
     - parameter request: The parameters of the request.
     - throws: `ELLocationError.LocationServicesDisabled` if location services are disabled on the device.
     */
    public func registerListener(listener: AnyObject, request: LocationUpdateRequest) throws {
        try locationProvider.registerListener(listener, request: request)
    }

    /**
     Deregisters a listener from receiving any more location updates.

     - parameter listener: The listener to deregister.
     */
    public func deregisterListener(listener: AnyObject) {
        locationProvider.deregisterListener(listener)
    }

    public init() {
        self.init(locationProvider: LocationManager.shared)
    }

    init(locationProvider: LocationUpdateProvider) {
        self.locationProvider = locationProvider
    }
}
