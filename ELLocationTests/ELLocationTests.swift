//
//  ELLocationTests.swift
//  ELLocationTests
//
//  Created by Sam Grover on 3/19/15.
//  Copyright (c) 2015 WalmartLabs. All rights reserved.
//

import UIKit
import XCTest
import CoreLocation
@testable import ELLocation

class ELLocationTests: XCTestCase {
    
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
    
    func testDistanceFilterShouldChangeWithAccuracy() {
        let handler: LocationUpdateResponseHandler = { (success: Bool, location: CLLocation?, error: NSError?) in }
        let subject = LocationManager()
        
        // Note: behavior with no listeners is not defined.

        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Coarse, response: handler))
        XCTAssertEqual(subject.manager.distanceFilter, 500)
        subject.deregisterListener(self)
        
        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Good, response: handler))
        XCTAssertEqual(subject.manager.distanceFilter, 50)
        subject.deregisterListener(self)
        
        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Better, response: handler))
        XCTAssertEqual(subject.manager.distanceFilter, 5)
        subject.deregisterListener(self)
        
        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Best, response: handler))
        XCTAssertEqual(subject.manager.distanceFilter, 2)
        subject.deregisterListener(self)
    }
    
    func testDesiredAccuracyShouldChangeWithAccuracy() {
        let handler: LocationUpdateResponseHandler = { (success: Bool, location: CLLocation?, error: NSError?) in }
        let subject = LocationManager()
        
        // Note: behavior with no listeners is not defined.

        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Coarse, response: handler))
        XCTAssertEqual(subject.manager.desiredAccuracy, kCLLocationAccuracyKilometer)
        subject.deregisterListener(self)
        
        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Good, response: handler))
        XCTAssertEqual(subject.manager.desiredAccuracy, kCLLocationAccuracyHundredMeters)
        subject.deregisterListener(self)
        
        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Better, response: handler))
        XCTAssertEqual(subject.manager.desiredAccuracy, kCLLocationAccuracyNearestTenMeters)
        subject.deregisterListener(self)
        
        subject.registerListener(self, request: LocationUpdateRequest(accuracy: .Best, response: handler))
        XCTAssertEqual(subject.manager.desiredAccuracy, kCLLocationAccuracyBest)
        subject.deregisterListener(self)
    }
}
