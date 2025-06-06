# Step Logger 🚶‍♂️

![Version](https://img.shields.io/badge/pub-v1.0.1--beta.2-blue)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-blue)

A Flutter plugin for cross-platform step tracking with background support.

## Features

- 📊 Real-time step counting 
- 🔄 Background service for continuous tracking (Android)
- 📅 Historical session data storage
- 🔔 Customizable notification
- 📱 Works in foreground and background
- 🔄 Automatic session recovery after app kills

## Platform Support

<table>
  <tr>
    <th>Feature</th>
    <th>Android</th>
    <th>iOS</th>
  </tr>
  <tr>
    <td>Real-time steps</td>
    <td>✅</td>
    <td>✅</td>
  </tr>
  <tr>
    <td>Background tracking</td>
    <td>✅</td>
    <td>⚠️ Limited</td>
  </tr>
  <tr>
    <td>Session history</td>
    <td>✅</td>
    <td>✅</td>
  </tr>
  <tr>
    <td>Step accuracy</td>
    <td>High</td>
    <td>High</td>
  </tr>
  <tr>
    <td>Battery impact</td>
    <td>Moderate</td>
    <td>Low</td>
  </tr>
</table>

## Android Setup
### Permissions ⚙️

Add to ```android/app/src/main/AndroidManifest.xml```:

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.BODY_SENSORS" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<!-- For Android 9+ background execution -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />
```

## Service declaration

```xml
   <service
      android:name="com.transistorsoft.flutter.backgroundfetch.BackgroundFetchService"
      android:permission="android.permission.BIND_JOB_SERVICE"
      android:exported="true" />

  <service
      android:name="id.flutter.flutter_background_service.BackgroundService"
      android:foregroundServiceType="health"/>

  <service
      android:name="com.your.example_app.ForegroundService"
      android:enabled="true"
      android:exported="false" />                  
```

## iOS Setup

### Requirements

1. **Add HealthKit entitlement:**
   - In Xcode, go to your target's **Signing & Capabilities**.
   - Click "+" and add **HealthKit**.

2. **Add these entries to your `Info.plist`:**

```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to HealthKit to track your steps</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We need access to HealthKit to save your step data</string>
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>healthkit</string>
</array>

<!-- Notification-->
<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
```

## iOS Limitations  
⚠️ **Important iOS Considerations**

1. **Background step updates require explicit user permission.**
2. **Steps are only recorded when:**
   - The app is in the foreground.
   - The user has HealthKit background delivery enabled.
   - The user opens the app periodically (to sync latest data).
     
3. **Step data accuracy depends on the device**
     
4. **Sessions interrupted by app kills will:**
   - Persist tracking state.
   - Recover steps when the app relaunches.
   - Auto-stop sessions older than 12 hours.

> **Note:** iOS does not support true background step tracking services like Android. The plugin uses HealthKit background delivery as a workaround, which depends on system scheduling and user permissions. This means background updates may be delayed or less frequent compared to Android, and step counts are calculated when the app is brought to the foreground.

