#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import "GoogleMaps/GoogleMaps.h"
@import GoogleMobileAds;
@implementation AppDelegate

// Common Problems:
// #1: Active Architecture
// (Flutter is not supported in Release on the simulator.)
// https://stackoverflow.com/questions/60558104/getting-error-while-building-ios-app-from-flutter
//
// #2: Could not setup VM data to bootstrap the VM from.
// Android Studio:
// - Flutter -> Clean
// - Flutter -> Open iOS module in Xcode

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GMSServices provideAPIKey:@"AIzaSyDZY7cVWs-bKnfyVW88BltsKd7IpYxu-Qo"];
    [[GADMobileAds sharedInstance] startWithCompletionHandler:nil];
//    GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = @[ @"abed5c3de5e25479dc8213ade8ac8191" ]; // Sample device ID
    [GeneratedPluginRegistrant registerWithRegistry:self];
    // Override point for customization after application launch.
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
