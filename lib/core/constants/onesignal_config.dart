class OneSignalConfig {
  /// OneSignal App ID
  /// https://onesignal.com dashboard -> Settings -> Keys & IDs sayfasındaki App ID
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'bc0c0b94-e465-4b0f-b01c-581d848df2ca',
  );
}
