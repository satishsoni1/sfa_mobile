class ApiConstants {
  // 1. BASE URL
  // Use '10.0.2.2' for Android Emulator to access localhost
  // Use your computer's IP address (e.g., '192.168.1.5') for Real Devices
  // Use your live domain (e.g., 'https://api.example.com') for Production
  
  static const String baseUrl = "http://10.0.2.2:8000/api"; 
  // static const String baseUrl = "http://192.168.1.X:8000/api"; 

  // 2. TIMEOUTS
  static const int connectionTimeout = 15000; // 15 seconds
  static const int receiveTimeout = 15000;

  // 3. ENDPOINTS (Optional: If you want to centralize paths)
  static const String login = "$baseUrl/login";
  static const String doctors = "$baseUrl/doctors";
  static const String visits = "$baseUrl/visits";
  static const String attendance = "$baseUrl/attendance";
}