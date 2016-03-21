//
//  ELLocationError.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

import ELFoundation

public let ELLocationErrorDomain = "ELLocationErrorDomain"

public enum ELLocationError: Int, NSErrorEnum {
    /// The user's device has been configured to restrict access to location services.
    case AuthorizationRestricted
    /// The user has denied access to location services.
    case AuthorizationDenied
    /// The callers is asking for authorization, but the corresponding description is missing from Info.plist
    case UsageDescriptionMissing
    /// The caller is asking for authorization 'always' but user has granted 'when in use'.
    case AuthorizationWhenInUse
    /// Location services are disabled.
    case LocationServicesDisabled

    public var domain: String {
        return ELLocationErrorDomain
    }

    public var errorDescription: String {
        switch self {
        case .AuthorizationRestricted:
            return "The user has been restricted from using location services."
        case .AuthorizationDenied:
            return "The user has denied location services in Settings."
        case .UsageDescriptionMissing:
            return "No description for the requested usage authorization has been provided in the app."
        case .AuthorizationWhenInUse:
            return "The user has granted permission to location services only when the app is in use."
        case .LocationServicesDisabled:
            return "Location services are not enabled."
        }
    }
}

