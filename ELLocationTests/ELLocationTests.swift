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
    
    // MARK: Request authorization
    
    func testRequestAuthPreconditions() {
        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)

        manager.withServicesEnabled(false) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNotNil(error, "Request auth returns error when location services are disabled")
        }
        
        manager.withAuthorizationStatus(.Denied) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNotNil(error, "Request auth returns error when authorization is denied")
        }

        manager.withAuthorizationStatus(.Restricted) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNotNil(error, "Request auth returns error when authorization is restricted")
        }

        manager.withAuthorizationStatus(.AuthorizedWhenInUse) {
            let error = subject.requestAuthorization(.Always)
            XCTAssertNotNil(error, "Request auth returns error for .Always when existing authorization is only .WhenInUse")
        }
    }

    func testRequestAuth() {
        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)

        manager.withAuthorizationStatus(.AuthorizedWhenInUse) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNil(error, "Request auth does not return error when already authorized")
            XCTAssertNil(manager.requestedAuthorizationStatus, "Request auth does nothing when already authorized")
        }

        manager.withAuthorizationStatus(.AuthorizedAlways) {
            let error = subject.requestAuthorization(.Always)
            XCTAssertNil(error, "Request auth does not return error when already authorized")
            XCTAssertNil(manager.requestedAuthorizationStatus, "Request auth does nothing when already authorized")
        }

        manager.withAuthorizationStatus(.NotDetermined) {
            subject.requestAuthorization(.WhenInUse)
            XCTAssertEqual(manager.requestedAuthorizationStatus, .AuthorizedWhenInUse, "Requests auth when necessary")
        }

        manager.withAuthorizationStatus(.NotDetermined) {
            subject.requestAuthorization(.Always)
            XCTAssertEqual(manager.requestedAuthorizationStatus, .AuthorizedAlways, "Requests auth when necessary")
        }
    }
    
    // MARK: Location Updates

    func testLocationMonitoring() {
        // Monitoring is dependent on the authorization status, accuracy and update frequency. These nested for loops
        // allow the test to cover all possible combinations.

        for authorizationStatus: CLAuthorizationStatus in [.NotDetermined, .Denied, .Restricted, .AuthorizedWhenInUse, .AuthorizedAlways] {
            for accuracy: LocationAccuracy in [.Coarse, .Good, .Better, .Best] {
                for updateFrequency: LocationUpdateFrequency in [.ChangesOnly, .Continuous] {
                    testLocationMonitoring(authorizationStatus: authorizationStatus, accuracy: accuracy, updateFrequency: updateFrequency)
                }
            }
        }
    }

    func testLocationMonitoring(authorizationStatus authorizationStatus: CLAuthorizationStatus, accuracy: LocationAccuracy, updateFrequency: LocationUpdateFrequency) {
        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)

        var expectGPS: Bool
        var expectCellular: Bool

        switch (authorizationStatus, accuracy, updateFrequency) {
        case (.NotDetermined, _, _), (.Denied, _, _), (.Restricted, _, _):
            // Any form of not-yet-authorized prevents any monitoring:
            expectGPS = false
            expectCellular = false
        case (.AuthorizedAlways, .Coarse, .ChangesOnly):
            // For (only) this specific combination, we should get Cellular tracking:
            expectGPS = false
            expectCellular = true
        default:
            // Otherwise, we should get GPS tracking:
            expectGPS = true
            expectCellular = false
        }

        // Set the auth status, add a listener and see what happens:

        manager.withAuthorizationStatus(authorizationStatus) {
            // Without any listeners, the monitoring should be off:
            XCTAssertFalse(manager.updatingLocation, "No listeners means no GPS tracking")
            XCTAssertFalse(manager.monitoringSignificantLocationChanges, "No listeners means no Cellular tracking")

            subject.withListener(accuracy: accuracy, updateFrequency: updateFrequency) {
                if expectGPS {
                    XCTAssertTrue(manager.updatingLocation, "\(accuracy)/\(updateFrequency) listener triggers GPS tracking")
                } else {
                    XCTAssertFalse(manager.updatingLocation, "\(accuracy)/\(updateFrequency) listener does not trigger GPS tracking")
                }

                if expectCellular {
                    XCTAssertTrue(manager.monitoringSignificantLocationChanges, "\(accuracy)/\(updateFrequency) listener triggers Cellular tracking")
                } else {
                    XCTAssertFalse(manager.monitoringSignificantLocationChanges, "\(accuracy)/\(updateFrequency) listener does not trigger Cellular tracking")
                }
            }
        }
    }

    func testLocationMonitoringWithMultipleListeners() {
        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)

        manager.withAuthorizationStatus(.AuthorizedWhenInUse) {
            XCTAssertFalse(manager.updatingLocation, "Before adding listeners, location is not updating (GPS)")

            subject.withListener(accuracy: .Good, updateFrequency: .Continuous) {
                XCTAssertTrue(manager.updatingLocation, "Adding a listener initiates location updates")

                subject.withListener(accuracy: .Good, updateFrequency: .Continuous) {
                    XCTAssertTrue(manager.updatingLocation, "Adding a second listener continues location updates")
                }

                XCTAssertTrue(manager.updatingLocation, "Removing second listener does not stop location updates")
            }

            XCTAssertFalse(manager.updatingLocation, "Removing all listeners stop location updates")
        }
    }
    
    // MARK: Distance filter

    func testDistanceFilterShouldChangeWithAccuracy() {
        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)

        let coarseListener = NSObject()
        let goodListener = NSObject()
        let betterListener = NSObject()
        let bestListener = NSObject()

        // Note: behavior with no listeners is not defined.

        // Add listeners from lowest to highest accuracy and verify that distance filter decreases:

        subject.registerListener(coarseListener, request: LocationUpdateRequest(accuracy: .Coarse) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.distanceFilter, 500)

        subject.registerListener(goodListener, request: LocationUpdateRequest(accuracy: .Good) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.distanceFilter, 50)

        subject.registerListener(betterListener, request: LocationUpdateRequest(accuracy: .Better) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.distanceFilter, 5)

        subject.registerListener(bestListener, request: LocationUpdateRequest(accuracy: .Best) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.distanceFilter, 2)

        // Remove listeners from lowest to highest accuracy and verify that distance filter DOES NOT CHANGE:

        subject.deregisterListener(coarseListener)
        XCTAssertEqual(manager.distanceFilter, 2)

        subject.deregisterListener(goodListener)
        XCTAssertEqual(manager.distanceFilter, 2)

        subject.deregisterListener(betterListener)
        XCTAssertEqual(manager.distanceFilter, 2)
    }

    // MARK: Desired accuracy
    
    func testDesiredAccuracyShouldChangeWithAccuracy() {
        let manager = MockCLLocationManager()
        let subject = LocationManager(manager: manager)

        let coarseListener = NSObject()
        let goodListener = NSObject()
        let betterListener = NSObject()
        let bestListener = NSObject()

        // Note: behavior with no listeners is not defined.

        // Add listeners from lowest to highest accuracy and verify that desired accuracy increases:

        subject.registerListener(coarseListener, request: LocationUpdateRequest(accuracy: .Coarse) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyKilometer)

        subject.registerListener(goodListener, request: LocationUpdateRequest(accuracy: .Good) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyHundredMeters)

        subject.registerListener(betterListener, request: LocationUpdateRequest(accuracy: .Better) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyNearestTenMeters)

        subject.registerListener(bestListener, request: LocationUpdateRequest(accuracy: .Best) { (success, location, error) -> Void in })
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyBest)

        // Remove listeners from lowest to highest accuracy and verify that desired accuracy DOES NOT CHANGE:

        subject.deregisterListener(coarseListener)
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyBest)

        subject.deregisterListener(goodListener)
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyBest)

        subject.deregisterListener(betterListener)
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyBest)
    }
}
