//
//  THGLocationTests.swift
//  THGLocationTests
//
//  Created by Sam Grover on 3/19/15.
//  Copyright (c) 2015 Set Direction. All rights reserved.
//

import UIKit
import XCTest
import CoreLocation
@testable import THGLocation

class THGLocationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCalculateAndUpdateAccuracyCrash() {
        LocationAuthorizationService().requestAuthorization(.WhenInUse)
        LocationAuthorizationService().requestAuthorization(.Always)
        
        // no crash here is a test success
        LocationManager.shared.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: 42, longitude: 42)])
    }
}
