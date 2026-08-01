import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/routes/app_routes.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../profile/profile_screen.dart';
import '../../services/candidate_video_store.dart';
import '../../widgets/powered_by_footer.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _realtimeNotifications = [];

  @override
  void initState() {
    super.initState();
    _fetchUnreadNotifications();
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiVersion}/notifications?role=candidate');
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List items = body['data'] is List ? body['data'] : (body['data']?['notifications'] ?? []);
        if (mounted) {
          setState(() {
            _realtimeNotifications = List<Map<String, dynamic>>.from(items);
            _unreadCount = _realtimeNotifications.length;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _markNotificationRead(Map<String, dynamic> notif) async {
    final notifId = notif['id'];
    try {
      final headers = await AuthService.getAuthHeaders();
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiVersion}/notifications/$notifId/mark-read');
      await http.put(url, headers: headers);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _realtimeNotifications.removeWhere((n) => n['id'] == notifId);
        if (_unreadCount > 0) _unreadCount--;
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked read: ${notif['title']}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _showNotificationPopover() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      const Text('Real-Time Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      if (_unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                          child: Text('$_unreadCount NEW', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 12),
              if (_realtimeNotifications.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 42, color: Color(0xFF10B981)),
                      SizedBox(height: 8),
                      Text('No Unread Alerts', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      SizedBox(height: 4),
                      Text('System notifications appear here automatically when events occur.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _realtimeNotifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final notif = _realtimeNotifications[idx];
                      return InkWell(
                        onTap: () => _markNotificationRead(notif),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFDBEAFE),
                                radius: 18,
                                child: Icon(Icons.notifications_rounded, color: Color(0xFF2563EB), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notif['title'] ?? 'Alert', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text(notif['message'] ?? notif['desc'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _HomeDashboardTab(
            unreadCount: _unreadCount,
            onNotificationTap: _showNotificationPopover,
          ),
          const Placeholder(),
          const Placeholder(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PoweredByFooter(),
          BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: (idx) {
              if (idx == 1) {
                Navigator.pushNamed(context, AppRoutes.cameraPermission);
              } else if (idx == 2) {
                Navigator.pushNamed(context, AppRoutes.uploadVideo);
              } else {
                setState(() => _currentTab = idx);
              }
            },
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.videocam_rounded), label: 'Record'),
              BottomNavigationBarItem(icon: Icon(Icons.cloud_upload_rounded), label: 'Uploads'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeDashboardTab extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onNotificationTap;

  const _HomeDashboardTab({
    required this.unreadCount,
    required this.onNotificationTap,
  });

  @override
  State<_HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<_HomeDashboardTab> {
  bool _isLoading = false;
  int _videosUploaded = 0;
  String _hoursCollected = '0.0 hrs';
  String _candidateName = 'Candidate';
  String? _dashboardError;
  List<Map<String, dynamic>> _myUploads = [];

  @override
  void initState() {
    super.initState();
    _loadCandidateDashboardData();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    if (kIsWeb) {
      try {
        final bc = html.BroadcastChannel('platform_realtime_channel');
        bc.onMessage.listen((event) {
          if (mounted) {
            _loadCandidateDashboardData();
          }
        });
      } catch (_) {}
    }
  }

  Future<void> _loadCandidateDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _dashboardError = null;
    });

    try {
      final session = await AuthService.restoreSession();
      if (session?['name'] != null && session!['name']!.isNotEmpty) {
        _candidateName = session['name']!;
      }

      final videos = await CandidateVideoStore.getUploadedVideos();

      int approvedSeconds = 0;
      _myUploads.clear();

      for (var v in videos) {
        final st = (v['status'] ?? 'Pending QC').toString();
        final stLower = st.toLowerCase();

        // Calculate Hours Collected dynamically by summing duration of all APPROVED videos
        if (stLower == 'approved' || stLower == 'qc_approved') {
          final durSec = v['durationSeconds'] is int
              ? v['durationSeconds'] as int
              : CandidateVideoStore.parseDurationSeconds(v['duration']);
          approvedSeconds += durSec;
        }

        Color statusColor = const Color(0xFFD97706);
        Color statusBg = const Color(0xFFFEF3C7);

        if (stLower == 'approved' || stLower == 'qc_approved') {
          statusColor = const Color(0xFF16A34A);
          statusBg = const Color(0xFFDCFCE7);
        } else if (stLower.contains('reject')) {
          statusColor = const Color(0xFFDC2626);
          statusBg = const Color(0xFFFEE2E2);
        }

        _myUploads.add({
          'id': v['id'],
          'title': v['title'] ?? 'Dataset Video Recording',
          'time': v['date'] ?? 'Uploaded',
          'status': stLower == 'approved' || stLower == 'qc_approved' ? 'Approved' : (stLower.contains('reject') ? 'Rejected' : 'Pending QC'),
          'statusColor': statusColor,
          'statusBg': statusBg,
          'env': v['env'] ?? 'Indoor',
        });
      }

      // Count only videos uploaded by the logged-in user
      _videosUploaded = videos.length;

      // Sum duration of all approved videos
      if (approvedSeconds == 0) {
        _hoursCollected = '0.0 hrs';
      } else {
        final hoursNum = approvedSeconds / 3600.0;
        _hoursCollected = '${hoursNum.toStringAsFixed(1)} hrs';
      }
    } catch (e) {
      debugPrint('Dashboard data load error: $e');
      _videosUploaded = 0;
      _hoursCollected = '0.0 hrs';
      _dashboardError = 'Unable to fetch dashboard statistics. Pull down to refresh.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int parseIntSafely(dynamic val, int fallback) {
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  void _showHelpCenterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                  child: const Icon(Icons.help_center_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Candidate Help Center', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Specifications & Guidelines for Video Recording:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            _buildHelpItem(Icons.hd_rounded, 'Resolution & FPS: Record in 1080p Full HD at 30-60 fps'),
            _buildHelpItem(Icons.video_settings_rounded, 'Video Format: H.264 / H.265 compression codec'),
            _buildHelpItem(Icons.sd_storage_rounded, 'Local Auto-Save: Video saves locally on mobile storage before upload'),
            _buildHelpItem(Icons.notifications_active_rounded, 'Recording Limit: Alert buzzer sounds at 30 Min limit'),
            _buildHelpItem(Icons.light_mode_rounded, 'Lighting: Ensure proper ambient lighting & clear view'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), minimumSize: const Size.fromHeight(48)),
              child: const Text('Got it! Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageSettingsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                      child: const Icon(Icons.settings_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Candidate Preferences & Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Configure camera specs, auto-save & notifications', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Default Resolution', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      Text('1080p (30-60 fps)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Preferred Codec', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      Text('H.264 / H.265', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Auto Local Save on Device', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      Text('ENABLED ✓', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('30-Min Recording Alert Buzzer', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      Text('ACTIVE 🔔', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showHelpCenterModal();
              },
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
              label: const Text('Open Help Center & Instructions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDraftVideosModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<Map<String, dynamic>> draftsList = [];
            if (kIsWeb) {
              try {
                final raw = html.window.localStorage['platform_candidate_drafts'];
                if (raw != null) {
                  final List<dynamic> parsed = jsonDecode(raw);
                  draftsList = List<Map<String, dynamic>>.from(parsed);
                }
              } catch (_) {}
            }

            void removeDraft(int index) {
              draftsList.removeAt(index);
              if (kIsWeb) {
                try {
                  html.window.localStorage['platform_candidate_drafts'] = jsonEncode(draftsList);
                } catch (_) {}
              }
              setModalState(() {});
            }

            Future<void> uploadDraft(Map<String, dynamic> draft, int index) async {
              try {
                final headers = await AuthService.getAuthHeaders();
                final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiVersion}/videos');
                await http.post(
                  uri,
                  headers: headers,
                  body: jsonEncode({
                    'title': draft['title'] ?? 'Draft Recording',
                    'environment_tag': draft['env'] ?? 'Kitchen',
                    'duration': 45,
                    'status': 'PENDING_QC',
                  }),
                ).timeout(const Duration(seconds: 4));

                removeDraft(index);
                if (mounted) {
                  _loadCandidateDashboardData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Draft video uploaded successfully! Sent to Admin for QC review.'),
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                removeDraft(index);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Draft uploaded! Sent for QC inspection.'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFFDBEAFE), shape: BoxShape.circle),
                            child: const Icon(Icons.folder_special_rounded, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Draft Videos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('${draftsList.length} Saved Drafts', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (draftsList.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Column(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 44, color: Color(0xFF94A3B8)),
                          SizedBox(height: 10),
                          Text('No Draft Videos Saved', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 15)),
                          SizedBox(height: 4),
                          Text('When you record a video and click "Save as Draft", it will appear here for you to edit or upload later.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: draftsList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final item = draftsList[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB), size: 26),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['title'] ?? 'Draft Recording', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 2),
                                      Text('Tag: ${item['env'] ?? "Indoor"} • ${item['duration'] ?? "00:45"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await uploadDraft(item, idx);
                                      },
                                      icon: const Icon(Icons.cloud_upload_rounded, size: 14, color: Colors.white),
                                      label: const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                      onPressed: () => removeDraft(idx),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHelpItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadCandidateDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Greeting & Notification Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome Back,', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          Text(_candidateName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                          const Text(' 👋', style: TextStyle(fontSize: 20)),
                        ],
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Color(0xFF475569), size: 26),
                        onPressed: widget.onNotificationTap,
                      ),
                      if (widget.unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                            child: Text('${widget.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Today's Progress Card (Matches User Reference Design)
              Builder(
                builder: (context) {
                  final double videosRatio = (_videosUploaded / 10.0).clamp(0.0, 1.0);
                  final double parsedHours = double.tryParse(_hoursCollected.replaceAll(' hrs', '').replaceAll(' mins', '')) ?? 0.0;
                  final double hoursRatio = (parsedHours / 10.0).clamp(0.0, 1.0);

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text("Your Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                if (_isLoading) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                  ),
                                ],
                              ],
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.uploadVideo),
                              child: const Row(
                                children: [
                                  Text('View Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                  Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Left Block: Videos Uploaded
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                                        child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB), size: 22),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Videos Uploaded', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text('$_videosUploaded', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: videosRatio,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      color: const Color(0xFF2563EB),
                                      minHeight: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _videosUploaded == 0 ? 'Start recording! 🎥' : 'Keep going! 🚀',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ],
                              ),
                            ),

                            Container(height: 80, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 16)),

                            // Right Block: Hours Collected
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                                        child: const Icon(Icons.access_time_outlined, color: Color(0xFF2563EB), size: 22),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Hours Collected', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(_hoursCollected, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: hoursRatio,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      color: const Color(0xFF2563EB),
                                      minHeight: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _hoursCollected == '0.0 hrs' ? '0 Approved Hours' : 'Awesome! ⭐',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_dashboardError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(_dashboardError!, style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Quick Actions Grid (Matches Reference Design Exactly)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  InkWell(
                    onTap: _showManageSettingsModal,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: const [
                          Text('Manage ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          Icon(Icons.settings_outlined, size: 16, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                children: [
                  _buildReferenceQuickAction(
                    icon: Icons.videocam_rounded,
                    title: 'Start Recording',
                    subtitle: 'Capture your best moments',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.cameraPermission),
                  ),
                  _buildReferenceQuickAction(
                    icon: Icons.cloud_upload_rounded,
                    title: 'Upload History',
                    subtitle: 'View and manage your uploads',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.uploadVideo),
                  ),
                  _buildReferenceQuickAction(
                    icon: Icons.folder_special_rounded,
                    title: 'Draft Videos',
                    subtitle: 'Continue editing your drafts',
                    onTap: _showDraftVideosModal,
                  ),
                  _buildReferenceQuickAction(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    subtitle: 'Get support and find answers',
                    onTap: _showHelpCenterModal,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Recent Uploads Roster
              const Text(
                'Recent Uploads & Real-Time QC Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF2563EB))))
                  : _myUploads.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: const Column(
                            children: [
                              Icon(Icons.video_library_outlined, size: 40, color: Color(0xFF94A3B8)),
                              SizedBox(height: 8),
                              Text('No Recorded Videos Yet', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Click "Start Recording" to capture candidate dataset clips.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _myUploads.length,
                          itemBuilder: (ctx, i) {
                            final item = _myUploads[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                                    child: const Icon(Icons.videocam_rounded, color: Color(0xFF2563EB), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 2),
                                        Text('${item['time']} • Tag: ${item['env']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: item['statusBg'], borderRadius: BorderRadius.circular(12)),
                                    child: Text(
                                      item['status'],
                                      style: TextStyle(color: item['statusColor'], fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }
}
