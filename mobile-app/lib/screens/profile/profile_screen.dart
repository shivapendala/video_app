import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../config/routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _candidateName = 'Candidate User';
  String _candidateEmail = 'candidate@example.com';
  String _candidateId = 'CAN-2024-001';
  String _vendorId = 'VEN-001';
  String _initials = 'CU';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final session = await AuthService.restoreSession();
      if (session != null) {
        final name = session['name'] ?? 'Candidate User';
        final email = session['email'] ?? 'candidate@example.com';
        final id = session['id'] ?? 'CAN-2024-001';
        final vendor = session['vendorId'] ?? 'VEN-001';

        String initials = 'CU';
        final parts = name.trim().split(' ');
        if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
          initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
        }

        if (mounted) {
          setState(() {
            _candidateName = name;
            if (email.isNotEmpty) _candidateEmail = email;
            if (id.isNotEmpty) _candidateId = id.length > 8 ? id.substring(0, 8) : id;
            if (vendor.isNotEmpty) _vendorId = vendor;
            _initials = initials;
          });
        }
      }

      // Fetch live candidate profile details from API
      final headers = await AuthService.getAuthHeaders();
      final userId = await AuthService.getUserId();
      if (userId.isNotEmpty) {
        final uri = Uri.parse('${AuthService.baseUrl}/candidates');
        final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final List<dynamic> items = data['data'] is List ? data['data'] : (data['data']?['items'] ?? []);
          for (var c in items) {
            if (c['id']?.toString() == userId || c['email'] == _candidateEmail) {
              if (mounted) {
                setState(() {
                  if (c['full_name'] != null && c['full_name'].toString().isNotEmpty) {
                    _candidateName = c['full_name'];
                    final parts = _candidateName.trim().split(' ');
                    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
                      _initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
                      _initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
                    }
                  }
                  if (c['email'] != null && c['email'].toString().isNotEmpty) _candidateEmail = c['email'];
                  if (c['vendor_code'] != null && c['vendor_code'].toString().isNotEmpty) {
                    _vendorId = c['vendor_code'].toString();
                  } else if ((_vendorId == 'VEN-001' || _vendorId.isEmpty) && c['vendor_id'] != null && c['vendor_id'].toString().isNotEmpty) {
                    final vid = c['vendor_id'].toString();
                    _vendorId = vid.length > 8 ? vid.substring(0, 8) : vid;
                  }
                });
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Dynamic Avatar & Name Header
              CircleAvatar(
                radius: 46,
                backgroundColor: AppColors.primary,
                child: Text(_initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_candidateName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Verified', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dynamic Profile Info List (Candidate ID, Vendor ID, Email)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildInfoRow('Candidate ID', _candidateId),
                    const Divider(height: 1),
                    _buildInfoRow('Vendor ID', _vendorId),
                    const Divider(height: 1),
                    _buildInfoRow('Email', _candidateEmail),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // QR Code Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 100, color: AppColors.primary),
                      const SizedBox(height: 8),
                      const Text('Scan Candidate Verification QR Code', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                  label: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryLight)),
        ],
      ),
    );
  }
}
