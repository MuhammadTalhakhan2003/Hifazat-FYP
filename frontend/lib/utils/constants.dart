class Constants {
  // IMPORTANT: This URL is critical for connecting to your local backend.
  //
  // - If using the ANDROID EMULATOR, use 'http://10.0.2.2:8000/api'.
  //   The IP 10.0.2.2 is a special alias to your host loopback interface (i.e., 127.0.0.1 on your computer).
  //
  // - If using an iOS SIMULATOR (on a Mac), you can use 'http://127.0.0.1:8000/api' or 'http://localhost:8000/api'.
  //
  // - If running on a PHYSICAL DEVICE (Android or iOS), you must use your computer's network IP address.
  //   e.g., 'http://192.168.1.10:8000/api'. Your phone and computer must be on the SAME Wi-Fi network.
  //   You cannot use localhost or 127.0.0.1.
  //
  // Override at build time: flutter build web --dart-define=API_BASE_URL=https://.../api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );
}