//
//  LocationAuthorizationService.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

// A protocol for a type that wants to provide location authorization.
public protocol LocationAuthorizationProvider {
    func requestAuthorization(authorization: LocationAuthorization) -> NSError?
}

// The interface for requesting location authorization
public struct LocationAuthorizationService: LocationAuthorizationProvider {
    private let locationAuthorizationProvider: LocationAuthorizationProvider

    /**
     Request the specified authorization.

     - parameter authorization: The authorization being requested.
     - returns: An optional error that could happen when requesting authorization. See `ELLocationError`.
     */
    public func requestAuthorization(authorization: LocationAuthorization) -> NSError? {
        return locationAuthorizationProvider.requestAuthorization(authorization)
    }

    public init() {
        self.init(locationAuthorizationProvider: LocationManager.shared)
    }

    init(locationAuthorizationProvider: LocationAuthorizationProvider) {
        self.locationAuthorizationProvider = locationAuthorizationProvider
    }
}
