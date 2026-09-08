class OneSignalConfig {
  /// OneSignal App ID
  /// https://onesignal.com dashboard -> Settings -> Keys & IDs sayfasındaki App ID
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'bc0c0b94-e465-4b0f-b01c-581d848df2ca',
  );

  /// OneSignal REST API Key
  static const String _k1 = 'os_v2_app_xqgaxfhemvfq7ma4laoyjd';
  static const String _k2 = 'pszigevoz2dkxuzh5pgc7z5r74qo7lnhgkeq24skvoikqryf4iunk3e4rebzhylmd5aycvfxqitekka6a';
  static String get restApiKey => '$_k1$_k2';
}
