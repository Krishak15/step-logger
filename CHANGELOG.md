## 1.0.0-beta.1

- Initial beta release.
- Added basic functionality for step logging.
- Included persistent session tracking and background step detection.
- Improved Android service management and foreground notification handling.

## 1.0.0-beta.2

- Added Support for iOS

### Fixed

- **iOS Tracking Persistence**: Resolved issue where tracking status and session steps were reset when app was killed and reopened
- **Session History Preservation**: Fixed session history being cleared unexpectedly on iOS
- **Background Step Calculation**: Improved accuracy of step counting after app resumes from background/killed state

### Added

- **Enhanced State Recovery**: Automatic recovery of interrupted tracking sessions on app restart
- **Debug Logging**: Added detailed logging for tracking state changes and persistence operations
- **Session Validation**: Added checks for stale sessions (>12 hours old) with automatic cleanup

### Changed

- **Storage Structure**: Separated tracking state and session history in SharedPreferences for more reliable persistence
- **Initialization Flow**: Improved startup sequence to properly restore previous tracking state
- **Auto-Save Mechanism**: More frequent background saves while tracking is active (every 10 seconds)

### Bug fixes

### Known Issues

- iOS background step updates may still be delayed due to platform restrictions
- HealthKit permissions need to be granted for accurate step counting after app kills

## 1.0.0-beta.2

- Minor changes

## 1.0.0-beta.3

- include guide to change tracking notification icon

## 1.0.0-beta.4

### Fixed

- Fixed background service failure on Flutter SDK 3.29.0 or above.
    
