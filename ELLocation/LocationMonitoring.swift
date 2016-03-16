//
//  LocationMonitoring.swift
//  ELLocation
//
//  Created by Alex Johnson on 3/16/16.
//  Copyright © 2016 WalmartLabs. All rights reserved.
//

/**
 There are two kinds of location monitoring in iOS: significant updates and standard location monitoring.
 Significant updates are more power efficient, but have limitations on accuracy and update frequency.
 */
enum LocationMonitoring: Comparable {
    /// Monitor for only "significant updates" to the user's location (using cell towers only)
    case SignificantUpdates
    /// Monitor for all updates to the user's location (using GPS, WiFi, etc)
    case Standard
}

func < (lhs: LocationMonitoring, rhs: LocationMonitoring) -> Bool {
    switch (lhs, rhs) {
    case (.SignificantUpdates, .Standard):
        return true
    default:
        return false
    }
}
