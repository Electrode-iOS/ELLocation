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

class MockCLLocationManager: ELCLLocationManager {
    var coreLocationServicesEnabled: Bool = true
    var coreLocationAuthorizationStatus: CLAuthorizationStatus = .NotDetermined
    var requestedAuthorizationStatus: CLAuthorizationStatus? = nil

    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    
    var updatingLocation: Bool = false
    var monitoringSignificantLocationChanges: Bool = false

    weak var delegate: CLLocationManagerDelegate? = nil

    func requestAlwaysAuthorization() {
        requestedAuthorizationStatus = .AuthorizedAlways
    }

    func requestWhenInUseAuthorization() {
        requestedAuthorizationStatus = .AuthorizedWhenInUse
    }
    
    func startUpdatingLocation() {
        updatingLocation = true
    }

    func stopUpdatingLocation() {
        updatingLocation = false
    }

    func startMonitoringSignificantLocationChanges() {
        monitoringSignificantLocationChanges = true
    }

    func stopMonitoringSignificantLocationChanges() {
        monitoringSignificantLocationChanges = false
    }
}

class ELLocationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    private func deliverLocationUpdate(subject: LocationManager, latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        subject.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: latitude, longitude: longitude)])
    }
    
    func testAddListener() {
        let subject = LocationManager()
        let listener = NSObject()

        let responseReceived = expectationWithDescription("response received")
        let request = LocationUpdateRequest(accuracy: .Good) { (success, location, error) -> Void in
            responseReceived.fulfill()
        }

        subject.registerListener(listener, request:request)
        
        deliverLocationUpdate(subject, latitude: 42, longitude: 42)
        
        waitForExpectationsWithTimeout(1.0, handler: nil)
    }
    
    func testCalculateAndUpdateAccuracyCrash() {
        LocationAuthorizationService().requestAuthorization(.WhenInUse)
        LocationAuthorizationService().requestAuthorization(.Always)
        
        let subject = LocationManager()

        // no crash here is a test success
        subject.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: 42, longitude: 42)])
    }

    // MARK: Listeners
    
    // MARK: Distance filter

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
    
    // MARK: Desired accuracy

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
