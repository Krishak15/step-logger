# Step Logger 🚶‍♂️

![Version](https://img.shields.io/badge/pub-v1.0.0--beta.1-blue)

A Flutter plugin for logging step data (Android)

## Features

- 📊 Real-time step counting
- 🔄 Background service for continuous tracking (Android)
- ⏱️ Session-based step analytics
- 📅 Historical session data storage
- 🔔 Customizable background notification
- 📱 Works with both foreground and background apps

## Android Permissions ⚙️

Add these to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Core permissions -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Background service enhancements -->
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
      android:name="com.your.example.ForegroundService"
      android:enabled="true"
      android:exported="false" />                  
```
