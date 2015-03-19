//
//  FirstViewController.swift
//  THGLocationExample
//
//  Created by Sam Grover on 3/19/15.
//  Copyright (c) 2015 Set Direction. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        startLocationUpdates()
        
        let listener3: NSObject = NSObject()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000_000), dispatch_get_main_queue()) { () -> Void in
            let request = LocationUpdateRequest(accuracy: .Better) { (success, location, error) -> Void in
                if success {
                    println("LISTENER 3: success!!!!")
                } else {
                    if let theError = error {
                        println("LISTENER 3: error is \(theError.localizedDescription)")
                    }
                }
            }
            
            if let requestError = LocationService().addListener(listener3, request: request) {
                println("LISTENER 3: error in making request. error is \(requestError.localizedDescription)")
            } else {
                println("LISTENER 3 ADDED")
            }
            
            // Schedule removal after some time seconds
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5_000_000_000), dispatch_get_main_queue()) { () -> Void in
                println("REMOVING LISTENER 3")
                LocationService().removeListener(listener3)
            }
        }
        
        var listener4: NSObject = NSObject()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000_000), dispatch_get_main_queue()) { () -> Void in
            let request = LocationUpdateRequest(accuracy: .Best) { (success, location, error) -> Void in
                if success {
                    println("LISTENER 4: success!!!!")
                } else {
                    if let theError = error {
                        println("LISTENER 4: error is \(theError.localizedDescription)")
                    }
                }
            }
            
            if let requestError = LocationService().addListener(listener4, request: request) {
                println("LISTENER 4: error in making request. error is \(requestError.localizedDescription)")
            } else {
                println("LISTENER 4 ADDED")
            }
            
            // Schedule removal after some time seconds
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10_000_000_000), dispatch_get_main_queue()) { () -> Void in
                println("LETTING LISTENER 4 BE DEALLOCED")
                listener4 = NSObject()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func startLocationUpdates() {
        let request = LocationUpdateRequest(accuracy: .Good) { (success, location, error) -> Void in
            if success {
                println("LISTENER 2: success!!!!")
            } else {
                if let theError = error {
                    println("LISTENER 2: error is \(theError.localizedDescription)")
                }
            }
        }
        
        if let requestError = LocationService().addListener(self, request: request) {
            println("LISTENER 2: error in making request. error is \(requestError.localizedDescription)")
        } else {
            println("LISTENER 2 ADDED")
        }
        
        // Schedule removal after some time seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15_000_000_000), dispatch_get_main_queue()) { () -> Void in
            println("REMOVING LISTENER 2")
            LocationService().removeListener(self)
        }
    }    

}

