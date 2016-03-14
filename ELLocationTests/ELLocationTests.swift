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

    var mockCurrentLocation: CLLocation = CLLocation(latitude: 45.5179694, longitude: -122.6771358) {
        didSet {
            self.delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [mockCurrentLocation])
        }
    }

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

    func mockMoveByAtLeast(distance: CLLocationDistance) {
        let oldLocation = mockCurrentLocation
        var newLocation = oldLocation

        while newLocation.distanceFromLocation(oldLocation) < distance {
            newLocation = CLLocation(latitude: newLocation.coordinate.latitude + 0.000001, longitude: newLocation.coordinate.longitude + 0.000001)
        }

        mockCurrentLocation = newLocation
    }
}

// Convenience methods for testing:

extension MockCLLocationManager {
    func withMockServicesEnabled(enabled: Bool, closure: () -> Void) {
        let oldEnabled = coreLocationServicesEnabled
        coreLocationServicesEnabled = enabled
        closure()
        coreLocationServicesEnabled = oldEnabled
    }

    func withMockAuthorizationStatus(status: CLAuthorizationStatus, closure: () -> Void) {
        let oldStatus = coreLocationAuthorizationStatus
        coreLocationAuthorizationStatus = status
        closure()
        coreLocationAuthorizationStatus = oldStatus
    }
}

extension LocationUpdateService {
    func withMockListener(accuracy accuracy: LocationAccuracy, updateFrequency: LocationUpdateFrequency, closure: () -> Void) {
        let listener = NSObject()
        let request = LocationUpdateRequest(accuracy: accuracy, updateFrequency: updateFrequency) { (success, location, error) -> Void in }

        let error = registerListener(listener, request: request)
        XCTAssertNil(error, "Must be able to register a mock listener")

        closure()

        deregisterListener(listener)
    }

    // NOTE: The async testing is tightly coupled to the internal implementation (relying on use
    // of `dispatch_async` for listener callbacks), but I don't know a better way.
    // -- @nonsensery
    func waitForMockListenerCallbacks(continuation: () -> Void) {
        dispatch_async(dispatch_get_main_queue(), continuation)
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
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)
        let listener = NSObject()
        let request = LocationUpdateRequest() { (success, location, error) -> Void in }

        manager.withMockServicesEnabled(false) {
            let error1 = subject.registerListener(listener, request: request)
            XCTAssertNotNil(error1, "Register returns error when location services are disabled")
        }

        manager.withMockServicesEnabled(true) {
            let error2 = subject.registerListener(listener, request: request)
            XCTAssertNil(error2, "Register does not return error when location services are enabled")
        }
    }
    
    func testAddAndRemoveListener() {
        let manager = MockCLLocationManager()
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)
        let listener = NSObject()
        
        let done = expectationWithDescription("test finished")

        var responseReceived = false
        let request = LocationUpdateRequest() { (success, location, error) -> Void in
            responseReceived = true
        }

        // Add listener:
        subject.registerListener(listener, request:request)
        
        // Update location:
        manager.mockMoveByAtLeast(5)

        // Wait...
        subject.waitForMockListenerCallbacks() {
            // Verify that callback was received:
            XCTAssertTrue(responseReceived, "Registered listener receives callback")
            
            // Reset the flag:
            responseReceived = false
            
            // Remove listener:
            subject.deregisterListener(listener)
            
            // Update location:
            manager.mockMoveByAtLeast(5)

            // Wait...
            subject.waitForMockListenerCallbacks() {
                // Verify that callback was NOT received:
                XCTAssertFalse(responseReceived, "Deregistered listener no longer receives callback")

                // Done
                done.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(0.1) { (error: NSError?) -> Void in }
    }

    func testWeakListenerRefs() {
        let manager = MockCLLocationManager()
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)

        var listener: NSObject? = NSObject()
        weak var weakListener: NSObject? = listener

        let done = expectationWithDescription("test finished")

        var responseReceived = false
        let request = LocationUpdateRequest() { (success, location, error) -> Void in
            responseReceived = true
        }

        // Add listener:
        subject.registerListener(listener!, request:request)

        // Update location:
        manager.mockMoveByAtLeast(5)

        // Wait...
        subject.waitForMockListenerCallbacks() {
            // Verify that callback was received:
            XCTAssertTrue(responseReceived, "Registered listener receives callback")

            // Reset the flag:
            responseReceived = false

            // Allow listener to be deallocated:
            listener = nil
            XCTAssertNil(weakListener, "Location Manager does not prevent listener from being deallocated")

            // Update location:
            manager.mockMoveByAtLeast(5)

            // Wait...
            subject.waitForMockListenerCallbacks() {
                // Verify that callback was NOT received:
                XCTAssertFalse(responseReceived, "Deallocated listener no longer receives callback")

                // Done
                done.fulfill()
            }
        }

        waitForExpectationsWithTimeout(0.1) { (error: NSError?) -> Void in }
    }
    
    // MARK: Request authorization
    
    func testRequestAuthPreconditions() {
        let manager = MockCLLocationManager()
        let provider = LocationManager(manager: manager)
        let subject = LocationAuthorizationService(locationAuthorizationProvider: provider)

        manager.withMockServicesEnabled(false) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNotNil(error, "Request auth returns error when location services are disabled")
        }
        
        manager.withMockAuthorizationStatus(.Denied) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNotNil(error, "Request auth returns error when authorization is denied")
        }

        manager.withMockAuthorizationStatus(.Restricted) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNotNil(error, "Request auth returns error when authorization is restricted")
        }

        manager.withMockAuthorizationStatus(.AuthorizedWhenInUse) {
            let error = subject.requestAuthorization(.Always)
            XCTAssertNotNil(error, "Request auth returns error for .Always when existing authorization is only .WhenInUse")
        }
    }

    func testRequestAuth() {
        let manager = MockCLLocationManager()
        let provider = LocationManager(manager: manager)
        let subject = LocationAuthorizationService(locationAuthorizationProvider: provider)

        manager.withMockAuthorizationStatus(.AuthorizedWhenInUse) {
            let error = subject.requestAuthorization(.WhenInUse)
            XCTAssertNil(error, "Request auth does not return error when already authorized")
            XCTAssertNil(manager.requestedAuthorizationStatus, "Request auth does nothing when already authorized")
        }

        manager.withMockAuthorizationStatus(.AuthorizedAlways) {
            let error = subject.requestAuthorization(.Always)
            XCTAssertNil(error, "Request auth does not return error when already authorized")
            XCTAssertNil(manager.requestedAuthorizationStatus, "Request auth does nothing when already authorized")
        }

        manager.withMockAuthorizationStatus(.NotDetermined) {
            subject.requestAuthorization(.WhenInUse)
            XCTAssertEqual(manager.requestedAuthorizationStatus, .AuthorizedWhenInUse, "Requests auth when necessary")
        }

        manager.withMockAuthorizationStatus(.NotDetermined) {
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
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)

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

        manager.withMockAuthorizationStatus(authorizationStatus) {
            // Without any listeners, the monitoring should be off:
            XCTAssertFalse(manager.updatingLocation, "No listeners means no GPS tracking")
            XCTAssertFalse(manager.monitoringSignificantLocationChanges, "No listeners means no Cellular tracking")

            subject.withMockListener(accuracy: accuracy, updateFrequency: updateFrequency) {
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
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)

        manager.withMockAuthorizationStatus(.AuthorizedWhenInUse) {
            XCTAssertFalse(manager.updatingLocation, "Before adding listeners, location is not updating (GPS)")

            subject.withMockListener(accuracy: .Good, updateFrequency: .Continuous) {
                XCTAssertTrue(manager.updatingLocation, "Adding a listener initiates location updates")

                subject.withMockListener(accuracy: .Good, updateFrequency: .Continuous) {
                    XCTAssertTrue(manager.updatingLocation, "Adding a second listener continues location updates")
                }

                XCTAssertTrue(manager.updatingLocation, "Removing second listener does not stop location updates")
            }

            XCTAssertFalse(manager.updatingLocation, "Removing all listeners stop location updates")
        }
    }
    
    // MARK: Distance filter

    func testContinuousUpdatesDisablesDistanceFilter() {
        for accuracy: LocationAccuracy in [.Coarse, .Good, .Better, .Best] {
            let manager = MockCLLocationManager()
            let provider = LocationManager(manager: manager)
            let subject = LocationUpdateService(locationProvider: provider)
            
            subject.withMockListener(accuracy: accuracy, updateFrequency: .Continuous) {
                XCTAssertEqual(manager.distanceFilter, kCLDistanceFilterNone)
            }
        }
    }

    func testDistanceFilterShouldChangeWithAccuracy() {
        let manager = MockCLLocationManager()
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)

        let coarseListener = NSObject()
        let goodListener = NSObject()
        let betterListener = NSObject()
        let bestListener = NSObject()

        // Note: behavior with no listeners is not defined.

        // Add listeners from lowest to highest accuracy and verify that distance filter decreases:

        subject.registerListener(coarseListener, request: LocationUpdateRequest(accuracy: .Coarse) { _,_,_ in })
        XCTAssertEqual(manager.distanceFilter, 500)

        subject.registerListener(goodListener, request: LocationUpdateRequest(accuracy: .Good) { _,_,_ in })
        XCTAssertEqual(manager.distanceFilter, 50)

        subject.registerListener(betterListener, request: LocationUpdateRequest(accuracy: .Better) { _,_,_ in })
        XCTAssertEqual(manager.distanceFilter, 5)

        subject.registerListener(bestListener, request: LocationUpdateRequest(accuracy: .Best) { _,_,_ in })
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
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)

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

    // MARK: Accuracy in practice

    func testContinuousUpdates() {
        for accuracy: LocationAccuracy in [.Coarse, .Good, .Better, .Best] {
            let done = expectationWithDescription("\(accuracy) test finished")

            testContinuousUpdates(accuracy, then: done.fulfill)
        }

        waitForExpectationsWithTimeout(0.1) { (error: NSError?) -> Void in }
    }

    func testContinuousUpdates(accuracy: LocationAccuracy, then done: () -> Void) {
        let manager = MockCLLocationManager()
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)
        let listener = NSObject()

        var responseReceived = false
        let request = LocationUpdateRequest(accuracy: accuracy, updateFrequency: .Continuous) { (success, location, error) -> Void in
            responseReceived = true
        }

        // Add listener:
        subject.registerListener(listener, request:request)

        // Update location:
        manager.mockMoveByAtLeast(0.1)

        // Wait...
        subject.waitForMockListenerCallbacks() {
            // Verify that callback was received:
            XCTAssertTrue(responseReceived, "Registered listener receives callback (\(accuracy))")

            // Reset the flag:
            responseReceived = false

            // Update location (~0.5 meters away):
            manager.mockMoveByAtLeast(0.5)

            // Wait...
            subject.waitForMockListenerCallbacks() {
                // Verify that callback was received:
                XCTAssertTrue(responseReceived, "Registered listener receives callback (\(accuracy))")

                // DON'T FORGET THIS! If the listener is dealloced, it will not receive callbacks
                subject.deregisterListener(listener)

                done()
            }
        }
    }

    func testDiscreteUpdates() {
        // Note: .Best has a threshold of 0m which means it always acts like "continuous"
        let thresholds: [LocationAccuracy:CLLocationDistance] = [.Coarse: 500, .Good: 50, .Better: 5, .Best: 2]

        for (accuracy, threshold) in thresholds {
            let done = expectationWithDescription("\(accuracy) test finished")

            testDiscreteUpdates(accuracy, threshold: threshold, then: done.fulfill)
        }

        waitForExpectationsWithTimeout(0.1) { (error: NSError?) -> Void in }
    }

    func testDiscreteUpdates(accuracy: LocationAccuracy, threshold: CLLocationDistance, then done: () -> Void) {
        let manager = MockCLLocationManager()
        let provider = LocationManager(manager: manager)
        let subject = LocationUpdateService(locationProvider: provider)
        let listener = NSObject()

        var responseReceived = false
        let request = LocationUpdateRequest(accuracy: accuracy, updateFrequency: .ChangesOnly) { (success, location, error) -> Void in
            responseReceived = true
        }

        // Add listener:
        subject.registerListener(listener, request: request)

        // Update location:
        manager.mockMoveByAtLeast(0.001)

        // Wait...
        subject.waitForMockListenerCallbacks() {
            // Verify that callback was received:
            XCTAssertTrue(responseReceived, "Registered listener receives callback (\(accuracy))")

            // Reset the flag:
            responseReceived = false

            // Update location (still under the threshold):
            manager.mockMoveByAtLeast(threshold * 0.9)

            // Wait...
            subject.waitForMockListenerCallbacks() {
                // Verify that callback was received:
                XCTAssertFalse(responseReceived, "Registered listener does not receive callback (\(accuracy))")

                // Reset the flag:
                responseReceived = false

                // Update location (over the threshold):
                manager.mockMoveByAtLeast(threshold * 0.2)

                // Wait...
                subject.waitForMockListenerCallbacks() {
                    // Verify that callback was received:
                    XCTAssertTrue(responseReceived, "Registered listener receives callback (\(accuracy))")

                    // DON'T FORGET THIS! If the listener is dealloced, it will not receive callbacks
                    subject.deregisterListener(listener)
                
                    done()
                }
            }
        }
    }
}
