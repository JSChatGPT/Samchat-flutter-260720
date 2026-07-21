enum DevicePlatform { ios, android, web }

String devicePlatformToString(DevicePlatform p) {
  switch (p) {
    case DevicePlatform.ios:
      return 'ios';
    case DevicePlatform.android:
      return 'android';
    case DevicePlatform.web:
      return 'web';
  }
}
