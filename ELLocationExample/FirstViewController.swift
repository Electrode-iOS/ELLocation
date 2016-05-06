//
//  FirstViewController.swift
//  ELLocationExample
//
//  Created by Sam Grover on 3/19/15.
//  Copyright (c) 2015 WalmartLabs. All rights reserved.
//

import UIKit
import ELLocation

class FirstViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        startListener2()
        startListener3()
        startListener4()
    }

    private func startListener3() {
        let listener3: NSObject = NSObject()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000_000), dispatch_get_main_queue()) { () -> Void in
            let request = LocationUpdateRequest(accuracy: .Better, updateFrequency: .Continuous) { (success, location, error) -> Void in
                if success {
                    print("LISTENER 3: success!!!!")
                } else {
                    if let theError = error {
                        print("LISTENER 3: error is \(theError.localizedDescription)")
                    }
                }
            }

            do {
                try LocationUpdateService().registerListener(listener3, request: request)
            } catch  {
                print("LISTENER 3: error in making request. error is \(error)")
                return
            }

            print("LISTENER 3 ADDED")

            // Schedule removal after some time seconds
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5_000_000_000), dispatch_get_main_queue()) { () -> Void in
                print("REMOVING LISTENER 3")
                LocationUpdateService().deregisterListener(listener3)
            }
        }
    }

    private func startListener4() {
        var listener4: NSObject = NSObject()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000_000), dispatch_get_main_queue()) { () -> Void in
            let request = LocationUpdateRequest(accuracy: .Best, updateFrequency: .Continuous) { (success, location, error) -> Void in
                if success {
                    print("LISTENER 4: success!!!!")
                } else {
                    if let theError = error {
                        print("LISTENER 4: error is \(theError.localizedDescription)")
                    }
                }
            }

            do {
                try LocationUpdateService().registerListener(listener4, request: request)
            } catch {
                print("LISTENER 4: error in making request. error is \(error)")
                return
            }

            print("LISTENER 4 ADDED")

            // Schedule removal after some time seconds
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10_000_000_000), dispatch_get_main_queue()) { () -> Void in
                print("LETTING LISTENER 4 BE DEALLOCED")
                listener4 = NSObject()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func startListener2() {
        let request = LocationUpdateRequest(accuracy: .Good, updateFrequency: .Continuous) { (success, location, error) -> Void in
            if success {
                print("LISTENER 2: success!!!!")
            } else {
                if let theError = error {
                    print("LISTENER 2: error is \(theError.localizedDescription)")
                }
            }
        }

        do {
            try LocationUpdateService().registerListener(self, request: request)
        } catch {
            print("LISTENER 2: error in making request. error is \(error)")
            return
        }

        print("LISTENER 2 ADDED")

        // Schedule removal after some time seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15_000_000_000), dispatch_get_main_queue()) { () -> Void in
            print("REMOVING LISTENER 2")
            LocationUpdateService().deregisterListener(self)
        }
    }    

}

