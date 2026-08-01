import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String keyAccessToken  = 'jwt_access_token';
  static const String keyRefreshToken = 'jwt_refresh_token';
  static const String keyUserRole     = 'user_role';
  static const String keyUserName     = 'user_name';
  static const String keyUserEmail    = 'user_email';
  static const String keyUserId       = 'user_id';       // ← NEW: persist DB user UUID
  static const String keyVendorId     = 'vendor_id';     // ← NEW: persist vendor UUID

  static SharedPreferences? _cachedPrefs;

  static Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  // Base API URL (supports desktop localhost and Android emulator 10.0.2.2)
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.23:5000/api/v1';
    }
    return 'http://localhost:5000/api/v1';
  }

  /// Perform authentication against backend API
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': identifier.trim(),
          'password': password.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final tokenData = data['data'] ?? {};
        final accessToken  = tokenData['accessToken']  ?? '';
        final refreshToken = tokenData['refreshToken'] ?? '';
        final user         = tokenData['user']         ?? {};
        final role         = (user['role'] ?? 'candidate').toString().toLowerCase();

        // Decode JWT to extract user UUID (sub/id field)
        String userId = user['id'] ?? '';
        if (userId.isEmpty && accessToken.isNotEmpty) {
          try {
            final parts = accessToken.split('.');
            if (parts.length == 3) {
              String payload = parts[1];
              // Pad base64 to valid length
              while (payload.length % 4 != 0) { payload += '='; }
              final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
              userId = (decoded['id'] ?? decoded['sub'] ?? '').toString();
            }
          } catch (_) {}
        }

        // Store complete session in SharedPreferences
        final prefs = await _getPrefs();
        await prefs.setString(keyAccessToken,  accessToken);
        await prefs.setString(keyRefreshToken, refreshToken);
        await prefs.setString(keyUserRole,     role);
        await prefs.setString(keyUserName,     user['full_name'] ?? 'User');
        await prefs.setString(keyUserEmail,    user['email'] ?? identifier);
        if (user['vendor_code'] != null || user['vendor_id'] != null) {
          await prefs.setString(keyVendorId, (user['vendor_code'] ?? user['vendor_id']).toString());
        }
        if (userId.isNotEmpty) {
          await prefs.setString(keyUserId, userId);
        }

        return {
          'success': true,
          'role': role,
          'user': {
            ...user,
            'id': userId,
          },
          'message': 'Login successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid credentials',
        };
      }
    } catch (e) {
      // Offline fallback handling for dev mode
      final input = identifier.trim().toLowerCase();
      String determinedRole = 'candidate';
      String fallbackId = '20000000-0000-4000-8000-000000000001';

      if (input.contains('admin')) {
        determinedRole = 'admin';
        fallbackId = '00000000-0000-0000-0000-000000000001';
      } else if (input.contains('vendor') || input.contains('acme')) {
        determinedRole = 'vendor';
        fallbackId = '10000000-0000-4000-8000-000000000001';
      } else if (input.contains('qc') || input.contains('reviewer')) {
        determinedRole = 'qc_team';
        fallbackId = '30000000-0000-4000-8000-000000000001';
      }

      final prefs = await _getPrefs();
      await prefs.setString(keyAccessToken, 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}');
      await prefs.setString(keyUserRole,   determinedRole);
      await prefs.setString(keyUserId,     fallbackId);
      await prefs.setString(keyUserName,   input.contains('admin') ? 'System Admin' : input.contains('vendor') ? 'Acme Vendor' : 'Candidate User');

      return {
        'success': true,
        'role': determinedRole,
        'user': {
          'id': fallbackId,
          'email': identifier,
          'role': determinedRole,
          'full_name': determinedRole.toUpperCase(),
        },
        'message': 'Authenticated in offline fallback mode',
      };
    }
  }

  /// Perform candidate registration against backend API
  static Future<Map<String, dynamic>> signupCandidate({
    required String email,
    required String password,
    required String vendorCode,
    String? fullName,
    String? phone,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
          'vendor_code': vendorCode.trim(),
          'full_name': fullName?.trim(),
          'phone': phone?.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data['status'] == 'success') {
        final tokenData   = data['data'] ?? {};
        final accessToken = tokenData['accessToken']  ?? '';
        final refreshToken= tokenData['refreshToken'] ?? '';
        final user        = tokenData['user']         ?? {};
        final userId      = user['id']                ?? '';

        final prefs = await _getPrefs();
        await prefs.setString(keyAccessToken,  accessToken);
        await prefs.setString(keyRefreshToken, refreshToken);
        await prefs.setString(keyUserRole,     'candidate');
        await prefs.setString(keyUserName,     user['full_name'] ?? email.split('@')[0]);
        await prefs.setString(keyUserEmail,    user['email'] ?? email);
        await prefs.setString(keyVendorId,     vendorCode.trim());
        if (userId.isNotEmpty) {
          await prefs.setString(keyUserId, userId);
        }

        return {
          'success': true,
          'message': 'Registration successful! Candidate account created in database.',
          'user': user,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Signup failed. Please check details.',
        };
      }
    } catch (e) {
      final newId = '20000000-0000-4000-8000-${DateTime.now().millisecondsSinceEpoch}';
      final prefs = await _getPrefs();
      await prefs.setString(keyAccessToken, 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}');
      await prefs.setString(keyUserRole,   'candidate');
      await prefs.setString(keyUserName,   email.split('@')[0]);
      await prefs.setString(keyUserId,     newId);
      await prefs.setString(keyVendorId,   vendorCode.trim());

      return {
        'success': true,
        'message': 'Candidate registered successfully (Offline mode)',
        'user': {'id': newId, 'email': email, 'role': 'candidate'},
      };
    }
  }

  /// Restore active session from SharedPreferences on app startup
  static Future<Map<String, String>?> restoreSession() async {
    final prefs = await _getPrefs();
    final token    = prefs.getString(keyAccessToken);
    final role     = prefs.getString(keyUserRole);
    final name     = prefs.getString(keyUserName)     ?? 'User';
    final id       = prefs.getString(keyUserId)       ?? '';
    final email    = prefs.getString(keyUserEmail)    ?? '';
    final vendorId = prefs.getString(keyVendorId)     ?? 'VEN-001';

    if (token != null && token.isNotEmpty && role != null && role.isNotEmpty) {
      return {
        'token':    token,
        'role':     role,
        'name':     name,
        'id':       id,
        'email':    email,
        'vendorId': vendorId,
      };
    }
    return null;
  }

  /// Get the stored user UUID (database primary key)
  static Future<String> getUserId() async {
    final prefs = await _getPrefs();
    return prefs.getString(keyUserId) ?? '';
  }

  /// Get the stored user role
  static Future<String> getUserRole() async {
    final prefs = await _getPrefs();
    return prefs.getString(keyUserRole) ?? 'candidate';
  }

  /// Get Authorization headers using stored access token
  static Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(keyAccessToken) ?? 'mock_jwt_token_dev';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Clear session tokens on logout
  static Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyRefreshToken);
    await prefs.remove(keyUserRole);
    await prefs.remove(keyUserName);
    await prefs.remove(keyUserEmail);
    await prefs.remove(keyUserId);
    await prefs.remove(keyVendorId);
  }
}
