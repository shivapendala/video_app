import 'package:flutter/foundation.dart';

class ApiConstants {
  // Prevent instantiation
  ApiConstants._();

  /// Base URL for backend server
  /// Handles localhost for Web/Desktop/iOS vs 10.0.2.2 for Android Emulator
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
      if (host != 'localhost' && host != '127.0.0.1') {
        // Dedicated Subpath Deployment (e.g. elevateiq-softtech.com/video-platform/)
        return '$scheme://$host/video-platform-api';
      }
      return 'http://$host:5000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.178.34.58:5000';
    }
    return 'http://localhost:5000';
  }

  static const String apiVersion = '/api/v1';

  // API Endpoints
  static String get healthEndpoint => '/health';
  static String get adminsEndpoint => '$apiVersion/admins';
  static String get vendorsEndpoint => '$apiVersion/vendors';
  static String get candidatesEndpoint => '$apiVersion/candidates';
  static String get videosEndpoint => '$apiVersion/videos';
  static String get videoUploadEndpoint => '$apiVersion/videos/upload';
  static String get qcReviewsEndpoint => '$apiVersion/qc-reviews';
  static String get paymentsEndpoint => '$apiVersion/payments';

  // Request Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> getHeadersWithAuth([String? token]) {
    final Map<String, String> headers = Map.from(defaultHeaders);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers['Authorization'] = 'Bearer mock_jwt_token_dev';
    }
    return headers;
  }
}
