import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import 'auth_service.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class CandidateVideoStore {
  static int parseDurationSeconds(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    final str = val.toString().trim();
    if (str.isEmpty) return 0;

    final numVal = int.tryParse(str);
    if (numVal != null) return numVal;

    final cleanStr = str.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = cleanStr.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60) + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600) + (m * 60) + s;
    }
    return 0;
  }

  /// Unified loader for candidate uploaded videos with strict individual candidate scoping
  static Future<List<Map<String, dynamic>>> getUploadedVideos() async {
    final List<Map<String, dynamic>> allVideos = [];
    final Set<String> processedVideoIds = {};

    try {
      final headers = await AuthService.getAuthHeaders();
      final session = await AuthService.restoreSession();
      final currentUserId = session?['id'] ?? '';
      final currentUserEmail = session?['email'] ?? '';

      // 1. Fetch from PostgreSQL REST API
      final queryParam = currentUserId.isNotEmpty ? '?candidate_id=$currentUserId' : '';
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiVersion}/videos$queryParam');
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);

        for (var vid in items) {
          final cId = vid['candidate_id']?.toString() ?? vid['candidateId']?.toString() ?? '';
          final cEmail = vid['email']?.toString() ?? '';

          // Strict Candidate Scoping: verify owner matches logged-in user
          if (currentUserId.isNotEmpty || currentUserEmail.isNotEmpty) {
            final bool hasOwnerInfo = cId.isNotEmpty || cEmail.isNotEmpty;
            if (!hasOwnerInfo) continue;

            final bool matchesId = currentUserId.isNotEmpty && cId == currentUserId;
            final bool matchesEmail = currentUserEmail.isNotEmpty && cEmail.toLowerCase() == currentUserEmail.toLowerCase();

            if (!matchesId && !matchesEmail) continue;
          }

          final id = vid['id']?.toString() ?? '';

          if (id.isNotEmpty && processedVideoIds.contains(id)) continue;
          if (id.isNotEmpty) processedVideoIds.add(id);

          final st = (vid['status'] ?? 'pending').toString().toLowerCase();
          String statusText = 'Pending QC';
          if (st == 'approved' || st == 'qc_approved') statusText = 'Approved';
          if (st.contains('reject')) statusText = 'Rejected';

          allVideos.add({
            'id': id.isNotEmpty ? id : 'VID-${allVideos.length + 1}',
            'title': vid['title'] ?? 'Dataset Video Recording',
            'env': vid['environment_tag'] ?? 'Indoor',
            'status': statusText,
            'date': vid['recording_date'] != null ? 'Uploaded' : 'Just Now',
            'size': '10.0 MB',
            'duration': vid['duration'] != null ? vid['duration'].toString() : '30:00 Mins',
            'durationSeconds': parseDurationSeconds(vid['duration']),
            'reason': vid['rejection_reason'] ?? '',
          });
        }
      }
    } catch (_) {}

    // 2. Fetch from Web localStorage platform_qc_submissions
    if (kIsWeb) {
      try {
        final raw = html.window.localStorage['platform_qc_submissions'];
        if (raw != null) {
          final List<dynamic> list = jsonDecode(raw);
          final session = await AuthService.restoreSession();
          final currentUserEmail = session?['email'] ?? '';
          final currentUserId = session?['id'] ?? '';

          for (var item in list) {
            final cEmail = item['candidateEmail']?.toString() ?? '';
            final cId = item['candidateId']?.toString() ?? '';

            // Strict Candidate Scoping
            if (currentUserId.isNotEmpty || currentUserEmail.isNotEmpty) {
              final bool hasOwnerInfo = cId.isNotEmpty || cEmail.isNotEmpty;
              if (!hasOwnerInfo) continue;

              final bool matchesId = currentUserId.isNotEmpty && cId == currentUserId;
              final bool matchesEmail = currentUserEmail.isNotEmpty && cEmail.toLowerCase() == currentUserEmail.toLowerCase();

              if (!matchesId && !matchesEmail) continue;
            }

            final id = item['id']?.toString() ?? '';

            if (id.isNotEmpty && processedVideoIds.contains(id)) continue;
            if (id.isNotEmpty) processedVideoIds.add(id);

            allVideos.add({
              'id': id.isNotEmpty ? id : 'VID-${allVideos.length + 1}',
              'title': item['title'] ?? 'Uploaded Video',
              'env': item['env'] ?? 'Kitchen',
              'status': item['status'] == 'Pending' ? 'Pending QC' : (item['status'] ?? 'Approved'),
              'date': item['time'] ?? 'Just Now',
              'size': item['size'] ?? '10 MB',
              'duration': item['duration'] ?? '30:00 Mins',
              'durationSeconds': parseDurationSeconds(item['duration']),
              'reason': item['rejectionReason'] ?? '',
            });
          }
        }
      } catch (_) {}
    }

    return allVideos;
  }
}
