//
//  LocationAccuracy.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

/**
 More time and power is used going down this list as the system tries to provide a more accurate location,
 so be conservative according to your needs. `Good` should work well for most cases.
 */
public enum LocationAccuracy: Int, Comparable {
    case Coarse
    case Good
    case Better
    case Best
}

public func < (lhs: LocationAccuracy, rhs: LocationAccuracy) -> Bool {
    return lhs.rawValue < rhs.rawValue
}
