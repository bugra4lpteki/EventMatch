class OneSignalConfig {
  /// OneSignal App ID
  /// https://onesignal.com dashboard -> Settings -> Keys & IDs sayfasındaki App ID
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'd2bb525e-333e-48a0-bb65-8b3e34b92b6a', // Varsayılan veya env App ID
  );
}
