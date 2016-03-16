//
//  LocationAuthorization.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

public enum LocationAuthorization {
    /// Authorization for location services to be used only when the app is in use by the user.
    case WhenInUse
    /// Authorization for location services to be used at all times, even when the app is not in the foreground.
    case Always
}
