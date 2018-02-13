# ELLocation 

**Note:** This framework has been deprecated. It is no longer being actively maintained and will not be updated for future versions of Swift or iOS.

`ELLocation` is a wrapper around iOS's location services. Its goal is to provide convenient and concise wrappers to access `CLLocationManager` and friends.

## Requirements

ELLocation requires Swift 2.2, Xcode 7.3 and [ELFoundation](https://github.com/Electrode-iOS/ELFoundation).

[Electrode-iOS](https://github.com/Electrode-iOS/) frameworks are designed to live side-by-side in the file system, like so:

* \MyProject
* \MyProject\ELFoundation
* \MyProject\ELLocation

## Installation

Install by adding ELLocation.xcodeproj to your project and configuring your target to link ELLocation.framework.

## Usage

`ELLocation` can be used for authorizing for location services and for setting up an object to receive location updates.

### Authorization

**Important Note:** iOS requires that you add `NSLocationWhenInUseUsageDescription` and/or `NSLocationAlwaysUsageDescription` key to the `Info.plist` file for your app as per your needs. If you miss this step, nothing will work and there will be no message to indicate why.

iOS requires an app to request authorization from the user for the kind of location services it needs to use. With `ELLocation` the API looks like the following:

```Swift
if let anError = LocationAuthorizationService().requestAuthorization(.WhenInUse) {
    //TODO: Client needs to process error and re-request auth
} else {
    startLocationUpdates()
}
```

### Location Updates

In order for a caller to get location updates it must do the following:

```Swift
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
    if let addListenerError = LocationUpdateService().registerListener(self, request: request) {
        print("LISTENER 1: error in adding the listener. error is \(addListenerError.localizedDescription)")
    } else {
        print("LISTENER 1 ADDED")
    }
}
```

Note that there can be an error in setting up the request and that is returned right away rather than in the handler block. You should check for that.

It is also possible to limit the callback frequency using the `updateFrequency` parameter of `LocationUpdateRequest` like so:

```Swift
let request = LocationUpdateRequest(accuracy: .Good, updateFrequency: .ChangesOnly, ...)
```

Combining `accuracy: .Coarse` with `updateFrequency: .ChangesOnly`, along with `requestAuthorization(.Always)` yields the lowest battery usage, at the expense of less accurate location data and infrequent updates.

## License

The MIT License (MIT)

Copyright (c) 2015-2016 Walmart, and other Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
