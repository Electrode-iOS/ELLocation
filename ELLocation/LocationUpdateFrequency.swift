//
//  LocationUpdateFrequency.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

/**
 Callback frequency setting. Lowest power consumption is achieved by combining LocationUpdateFrequency.ChangesOnly
 with LocationAccuracy.Coarse

 - ChangesOnly: Notify listeners only when location changes. The granularity of this depends on the LocationAccuracy setting
 - Continuous:  Notify listeners at regular, frequent intervals (~1-2s)
*/
public enum LocationUpdateFrequency: Int, Comparable {
    case ChangesOnly
    case Continuous
}

public func < (lhs: LocationUpdateFrequency, rhs: LocationUpdateFrequency) -> Bool {
    return lhs.rawValue < rhs.rawValue
}
