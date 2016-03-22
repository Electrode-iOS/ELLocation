//
//  AppDelegate.swift
//  ELLocationExample
//
//  Created by Sam Grover on 3/19/15.
//  Copyright (c) 2015 WalmartLabs. All rights reserved.
//

import UIKit
import ELLocation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        requestLocationAuthorization()

        return true
    }

    private func requestLocationAuthorization() {
        do {
            try LocationAuthorizationService().requestAuthorization(.WhenInUse)
        } catch let requestAuthError as NSError {
            //TODO: Client needs to process error and re-request auth
            assert(requestAuthError.domain == ELLocationErrorDomain, "request authorization returned error with unexpected domain '\(requestAuthError.domain)'")
            print("REQUEST AUTH: error requesting authorization. error is \(requestAuthError.localizedDescription)")
            return
        }

        startLocationUpdates()
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func startLocationUpdates() {
        // Set up the request
        let request = LocationUpdateRequest(accuracy: .Good) { (success, location, error) -> Void in
            if success {
                if let actualLocation = location {
                    print("LISTENER 1: success! location is (\(actualLocation.coordinate.latitude), \(actualLocation.coordinate.longitude))")
                }
            } else {
                if let theError = error {
                    print("LISTENER 1: error is \(theError.localizedDescription)")
                }
            }
        }
        
        // Register the listener
        do {
            try LocationUpdateService().registerListener(self, request: request)
        } catch let addListenerError as NSError {
            print("LISTENER 1: error in adding the listener. error is \(addListenerError.localizedDescription)")
            return
        }

        print("LISTENER 1 ADDED")
    }
}
