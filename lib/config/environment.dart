class Environment {
  // Backend Configuration
  static const String backendBaseUrl = 'http://10.16.74.126:5000'; // Your network IP
  
  // App Configuration
  static const String appName = 'FRS Temple';
  static const String appVersion = '1.0.0';
  
  // Feature Flags
  static const bool enableBackendUpload = true;
  static const bool enableFaceRecognition = true;
  static const bool enableCloudStorage = true;
}
