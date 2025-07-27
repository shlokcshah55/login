# iOS Share Extension Xcode Setup Instructions

## Overview
You need to manually configure the Xcode project to add the Share Extension target and App Groups capability.

## Step 1: Open Xcode Project
1. Open `ios/Runner.xcworkspace` in Xcode (NOT the .xcodeproj file)
2. Wait for the project to load completely

## Step 2: Add Share Extension Target
1. In the project navigator, select the "Runner" project (top-level)
2. Click the "+" button at the bottom left of the targets list
3. Select "Share Extension" from the iOS > Application Extension templates
4. Configure the extension:
   - Product Name: `Share Extension`
   - Bundle Identifier: `com.srishlok.pinit.shareextension` (or your app's bundle ID + .shareextension)
   - Language: Swift
   - Use the existing ShareViewController.swift file we created

## Step 3: Replace Extension Files
1. Delete the auto-generated ShareViewController.swift from the new target
2. Add the existing files from `ios/Share Extension/` folder to the Share Extension target:
   - ShareViewController.swift
   - Info.plist
   - Base.lproj/MainInterface.storyboard

## Step 4: Configure App Groups
1. Select the "Runner" target
2. Go to "Signing & Capabilities" tab
3. Click "+" and add "App Groups"
4. Add a new app group: `group.com.srishlok.pinit` (replace with your bundle ID)
5. Repeat steps 1-4 for the "Share Extension" target

## Step 5: Add Build Settings
1. Select "Runner" target
2. Go to "Build Settings"
3. Search for "User-Defined"
4. Add new setting: `CUSTOM_GROUP_ID` = `group.com.srishlok.pinit`
5. Repeat for "Share Extension" target

## Step 6: Configure Deployment Target
1. Ensure both "Runner" and "Share Extension" targets have the same iOS Deployment Target (15.0)
2. This ensures compatibility

## Step 7: Build and Test
1. Run `flutter clean` from the project root
2. Run `cd ios && pod install`
3. Build the project in Xcode
4. Test on a device or simulator

## Step 8: Test with TikTok and Other Apps
1. Install TikTok on your test device
2. Open a TikTok video
3. Tap the Share button
4. Look for your app (Pinit) in the share sheet
5. Test with other apps like Instagram, Twitter, Safari, etc.

## Troubleshooting
- If you get "no such module 'receive_sharing_intent'" error:
  - Go to Runner target > Build Phases
  - Move "Embed Foundation Extension" to the top of "Thin Binary"
- If build fails, clean the build folder (Product > Clean Build Folder)
- If your app doesn't appear in TikTok share sheet:
  - Make sure you've installed the app on the device (not just simulator)
  - Check that the Share Extension target is properly configured
  - Verify App Groups are set up correctly
  - Try restarting the device after installing
- If sharing doesn't work:
  - Check the console logs in Xcode for error messages
  - Ensure the bundle identifier for Share Extension is correct
  - Verify that both targets have the same iOS deployment target

## What This Enables
- Share URLs and text from Safari to your app
- Share from other apps to your app
- Integration with iOS sharing system
- Automatic app launching when shared content is received

The Flutter code in `lib/main.dart` already handles the shared content processing.