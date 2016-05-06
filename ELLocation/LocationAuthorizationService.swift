//
//  LocationAuthorizationService.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

// A protocol for a type that wants to provide location authorization.
public protocol LocationAuthorizationProvider {
    func requestAuthorization(authorization: LocationAuthorization) throws
}

// The interface for requesting location authorization
public struct LocationAuthorizationService: LocationAuthorizationProvider {
    private let locationAuthorizationProvider: LocationAuthorizationProvider

    /**
     Request the specified authorization.

     - parameter authorization: The authorization being requested.
     - throws: `ELLocationError` if the authorization request is not possible. Note that an error
               is **not** thrown by this method if the user _declines_ to authorize access.
     */
    public func requestAuthorization(authorization: LocationAuthorization) throws {
        try locationAuthorizationProvider.requestAuthorization(authorization)
    }

    public init() {
        self.init(locationAuthorizationProvider: LocationManager.shared)
    }

    init(locationAuthorizationProvider: LocationAuthorizationProvider) {
        self.locationAuthorizationProvider = locationAuthorizationProvider
    }
}
