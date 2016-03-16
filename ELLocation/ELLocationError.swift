//
//  ELLocationError.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

import ELFoundation

let ELLocationErrorDomain: String = "ELLocationErrorDomain"

public enum ELLocationError: Int, NSErrorEnum {
    /// The user has denied access to location services or their device has been configured to restrict it.
    case AuthorizationDeniedOrRestricted
    /// The callers is asking for authorization, but the corresponding description is missing from Info.plist
    case UsageDescriptionMissing
    /// The caller is asking for authorization 'always' but user has granted 'when in use'.
    case AuthorizationWhenInUse
    /// Location services are disabled.
    case LocationServicesDisabled

    public var domain: String {
        return "io.theholygrail.ELLocationError"
    }

    public var errorDescription: String {
        switch self {
        case .AuthorizationDeniedOrRestricted:
            return "The user has denied location services in Settings or has been restricted from using them."
        case .UsageDescriptionMissing:
            return "No description for the requested usage authorization has been provided in the app."
        case .AuthorizationWhenInUse:
            return "The user has granted permission to location services only when the app is in use."
        case .LocationServicesDisabled:
            return "Location services are not enabled."
        }
    }
}

