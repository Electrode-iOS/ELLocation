//
//  LocationUpdateRequest.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

import CoreLocation

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
     Initializes a request to be used for registering for location updates.

     - parameter accuracy: The accuracy desired by the listener. Since there can be multiple listeners, the framework endeavors to provide the highest level of accuracy registered. Default value is `.Good`
     - parameter updateFrequency: The rate at which to notify the listener. Default value is `.Continuous`.
     - parameter response: This closure is called when a update is received or if there's an error.
     */
    public init(accuracy: LocationAccuracy = .Good, updateFrequency: LocationUpdateFrequency = .ChangesOnly, response: LocationUpdateResponseHandler) {
        self.accuracy = accuracy
        self.response = response
        self.updateFrequency = updateFrequency
    }
}
