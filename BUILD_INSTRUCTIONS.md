# Build Instructions

## General
1. Ensure that Admob is enabled.
   1. Ensure `Admob.initialize();` is uncommented and the real Admob IDs are in use.
1. Test the app locally on both an Android and iOS device.

## iOS
1. Open the app in Xcode. Open "Project Navigator" (top-left button in left pane). 
1. Click "Runner" and you should see the project properties. 
1. Increment the version and build number.
1. Change the Target to be: `Runner > Any iOS Device`.
1. Run `flutter build ios`
1. Build a new archive: `Product > Archive`.
1. Distribute App. Leave all the default options.
1. Collect a short video running on an iOS device (required for Apple approval).
1. Test the app out on TestFlight

## Android
1. Open `build.gradle` at the path `android > app > build.gradle`.
1. Increment the `versionCode` and `versionName`
1. Build for Android: `flutter build apk --split-per-abi`
