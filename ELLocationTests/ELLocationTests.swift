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

// Convenience methods for testing:

extension MockCLLocationManager {
    func withServicesEnabled(enabled: Bool, closure: () -> Void) {
        let oldEnabled = coreLocationServicesEnabled
        coreLocationServicesEnabled = enabled
        closure()
        coreLocationServicesEnabled = oldEnabled
    }

    func withAuthorizationStatus(status: CLAuthorizationStatus, closure: () -> Void) {
        let oldStatus = coreLocationAuthorizationStatus
        coreLocationAuthorizationStatus = status
        closure()
        coreLocationAuthorizationStatus = oldStatus
    }
}

extension LocationManager {
    func withListener(accuracy accuracy: LocationAccuracy, updateFrequency: LocationUpdateFrequency, closure: () -> Void) {
        let listener = NSObject()
        let request = LocationUpdateRequest(accuracy: accuracy, updateFrequency: updateFrequency) { (success, location, error) -> Void in }

        registerListener(listener, request: request)

        closure()

        deregisterListener(listener)
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

    func testCalculateAndUpdateAccuracyCrash() {
        LocationAuthorizationService().requestAuthorization(.WhenInUse)
        LocationAuthorizationService().requestAuthorization(.Always)
        
        let subject = LocationManager()

        // no crash here is a test success
        subject.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: 42, longitude: 42)])
    }

    // MARK: Listeners
    
    func testAddListenerPreconditions() {
        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)
        let listener = NSObject()
        let request = LocationUpdateRequest(accuracy: .Good) { (success, location, error) -> Void in }
        
        manager.withServicesEnabled(false) {
            let error1 = subject.registerListener(listener, request: request)
            XCTAssertNotNil(error1, "Register returns error when location services are disabled")
        }

        manager.withServicesEnabled(true) {
            let error2 = subject.registerListener(listener, request: request)
            XCTAssertNil(error2, "Register does not return error when location services are enabled")
        }
    }
    
    func testAddAndRemoveListener() {
        // FIXME: The async testing is tightly coupled to the internal implementation (relying on use
        // of `dispatch_async` for listener callbacks), but I don't know a better way.
        // -- @nonsensery

        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)
        let listener = NSObject()
        
        let done = expectationWithDescription("test finished")

        var responseReceived = false
        let request = LocationUpdateRequest(accuracy: .Good) { (success, location, error) -> Void in
            responseReceived = true
        }

        // Add listener:
        subject.registerListener(listener, request:request)
        
        // Update location:
        deliverLocationUpdate(subject, latitude: 42, longitude: -16)

        // Wait...
        dispatch_async(dispatch_get_main_queue()) {
            // Verify that callback was received:
            XCTAssertTrue(responseReceived, "Registered listener receives callback")
            
            // Reset the flag:
            responseReceived = false
            
            // Remove listener:
            subject.deregisterListener(listener)
            
            // Update location:
            self.deliverLocationUpdate(subject, latitude: 143, longitude: 85)
            
            // Wait...
            dispatch_async(dispatch_get_main_queue()) {
                // Verify that callback was NOT received:
                XCTAssertFalse(responseReceived, "Deregistered listener no longer receives callback")
                
                // Done
                done.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(0.1) { (error: NSError?) -> Void in }
    }
    
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
