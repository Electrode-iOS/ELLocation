## Introduction

Camelot provides the `THGLocation` module. `THGLocation` is intended to be a wrapper around iOS's location services. Its goal is to provide convenient and concise wrappers to access `CLLocationManager` and friends, thus enabling callers to get going with building their app. `THGLocation` is also designed to work well with, and to utilize other libraries in this organization.

## Usage

`THGLocation` can be used for authorizing for location services and for setting up an object to receive location updates.

### Authorization

**Important Note:** iOS requires that you add `NSLocationWhenInUseUsageDescription` and/or `NSLocationAlwaysUsageDescription` key to the `Info.plist` file for your app as per your needs. If you miss this step, nothing will work and there will be no message to indicate why.

iOS requires an app to request authorization from the user for the kind of location services it needs to use. With `THGLocation` the API looks like the following:

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
                println("LISTENER 1: success! location is (\(actualLocation.coordinate.latitude), \(actualLocation.coordinate.longitude))")
            }
        } else {
            if let theError = error {
                println("LISTENER 1: error is \(theError.localizedDescription)")
            }
        }
    }
    
    // Make the request
    if let requestError = LocationUpdateService().addListener(self, request: request) {
        println("LISTENER 1: error in making request. error is \(requestError.localizedDescription)")
    } else {
        println("LISTENER 1 ADDED")
    }
}
```

Note that there can me an error in setting up the request and that is returned right away rather than in the handler block. You should check for that.

## Dependencies

`THGLocation` is dependent on [Excalibur](https://github.com/TheHolyGrail/Dennis).

## Contributions

We appreciate your contributions to all of our projects and look forward to interacting with you via Pull Requests, the issue tracker, via Twitter, etc.  We're happy to help you, and to have you help us.  We'll strive to answer every PR and issue and be very transparent in what we do.

When contributing code, please refer to our Dennis (https://github.com/TheHolyGrail/Dennis).

###### THG's Primary Contributors

Dr. Sneed (@bsneed)<br>
Steve Riggins (@steveriggins)<br>
Sam Grover (@samgrover)<br>
Angelo Di Paolo (@angelodipaolo)<br>
Cody Garvin (@migs647)<br>
Wes Ostler (@wesostler)<br>

## License

The MIT License (MIT)

Copyright (c) 2015 Walmart, TheHolyGrail, and other Contributors

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

