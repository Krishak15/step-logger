class StepLoggerConfig {
  /// [enableTrackingNotification] Whether to enable the tracking notification.
  ///
  /// On Android, disabling the notification is limited because a background service
  /// must display a notification. On iOS, this flag controls whether a notification
  /// is shown during tracking.
  final bool enableTrackingNotification;
  final String? trackingNotificationTitle;
  final String? trackingNotificationContent;
  final String? androidNotificationIcon;

  const StepLoggerConfig({
    this.enableTrackingNotification = true,
    this.trackingNotificationTitle,
    this.trackingNotificationContent,
    this.androidNotificationIcon,
  });
}
