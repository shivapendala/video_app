import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../config/routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/powered_by_footer.dart';

class MobileQCDashboardScreen extends StatefulWidget {
  const MobileQCDashboardScreen({super.key});

  @override
  State<MobileQCDashboardScreen> createState() => _MobileQCDashboardScreenState();
}

class _MobileQCDashboardScreenState extends State<MobileQCDashboardScreen> {
  int _activeTab = 0; // 0: My Assigned Tickets, 1: In Review, 2: QC Approved, 3: QC Rejected
  bool _isLoading = false;

  // QC Sliders State for Active Review Item
  double _audioClarity = 4.0;
  double _lightingQuality = 4.0;
  double _framingScore = 5.0;
  double _envMatchScore = 5.0;

  final TextEditingController _rejectReasonCtrl = TextEditingController();

  Map<String, dynamic> _statistics = {
    'total_assigned': 0,
    'pending_review': 0,
    'in_review': 0,
    'approved': 0,
    'rejected': 0,
    'completed_today': 0,
  };

  List<Map<String, dynamic>> _myTickets = [];
  List<Map<String, dynamic>> _inReviewTickets = [];
  List<Map<String, dynamic>> _qcApprovedList = [];
  List<Map<String, dynamic>> _qcRejectedList = [];

  @override
  void initState() {
    super.initState();
    _fetchRealQCData();
    _subscribeBroadcastChannel();
    _pingActivityHeartbeat();
  }

  void _subscribeBroadcastChannel() {
    if (kIsWeb) {
      try {
        final bc = html.BroadcastChannel('platform_realtime_channel');
        bc.onMessage.listen((event) {
          if (mounted) {
            _fetchRealQCData();
          }
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _rejectReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pingActivityHeartbeat() async {
    try {
      final session = await AuthService.restoreSession();
      final reviewerId = session?['id'] ?? 'q0000000-0000-0000-0000-000000000001';
      final url = Uri.parse('${ApiConstants.baseUrl}/api/v1/qc-tickets/tickets/reviewer-activity');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reviewer_id': reviewerId,
          'activity_type': 'dashboard_view',
        }),
      );
    } catch (_) {}
  }

  Future<void> _fetchRealQCData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final session = await AuthService.restoreSession();
      final reviewerId = session?['id'] ?? 'q0000000-0000-0000-0000-000000000001';
      final userEmail = (session?['email'] ?? '').toString().toLowerCase();
      final userName = (session?['name'] ?? session?['username'] ?? '').toString().toLowerCase();

      final Set<String> processedIds = {};
      final List<Map<String, dynamic>> fetchedPending = [];
      final List<Map<String, dynamic>> fetchedInReview = [];
      final List<Map<String, dynamic>> fetchedApproved = [];
      final List<Map<String, dynamic>> fetchedRejected = [];

      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/api/v1/qc-tickets/tickets/my-tickets?reviewer_id=$reviewerId');
        final res = await http.get(url).timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['data'] != null && body['data'] is List) {
            final List rawList = body['data'];
            for (var t in rawList) {
              final id = (t['id'] ?? t['ticket_code'] ?? '').toString();
              if (id.isNotEmpty) processedIds.add(id);
              final st = (t['status'] ?? 'pending_qc').toString().toLowerCase();
              final map = Map<String, dynamic>.from(t);
              if (st == 'in_review') fetchedInReview.add(map);
              else if (st == 'qc_approved') fetchedApproved.add(map);
              else if (st == 'qc_rejected') fetchedRejected.add(map);
              else fetchedPending.add(map);
            }
          }
        }
      } catch (e) {
        debugPrint('QC Tickets API offline fallback: $e');
      }

      // Also read Web LocalStorage platform_qc_submissions for live Web updates
      if (kIsWeb) {
        try {
          final raw = html.window.localStorage['platform_qc_submissions'];
          if (raw != null) {
            final List<dynamic> list = jsonDecode(raw);
            for (var item in list) {
              final id = (item['id'] ?? item['raw_id'] ?? '').toString();
              if (id.isNotEmpty && processedIds.contains(id)) continue;

              final title = (item['title'] ?? '').toString().toLowerCase();
              final cName = (item['candidateName'] ?? item['candidate_name'] ?? '').toString().toLowerCase();
              final vName = (item['vendor'] ?? item['vendor_name'] ?? '').toString().toLowerCase();

              // Skip synthetic/mock test items
              if (title.contains('test') || cName.contains('test candidate') || vName.contains('test vendor')) {
                continue;
              }

              final assignedTo = (item['assignedTo'] ?? item['assigned_to'] ?? '').toString();
              final st = (item['status'] ?? 'Pending').toString().toLowerCase();

              // Check if video is assigned to QC Team
              final isAssigned = assignedTo.isNotEmpty && assignedTo != 'Unassigned';

              if (isAssigned) {
                if (id.isNotEmpty) processedIds.add(id);
                final formattedTicket = {
                  'id': id.isNotEmpty ? id : 'TKT-001',
                  'ticket_code': id.isNotEmpty ? id : 'TKT-001',
                  'title': item['title'] ?? 'Candidate Video Recording',
                  'candidate_name': item['candidateName'] ?? item['candidate_name'] ?? 'Candidate',
                  'vendor_name': item['vendor'] ?? item['vendor_name'] ?? 'Acme Video Solutions',
                  'duration': item['duration'] ?? '15 Mins',
                  'environment_tag': item['env'] ?? 'Indoor',
                  'audio_score': item['score'] ?? 95,
                  'status': st.contains('approved') ? 'qc_approved' : (st.contains('reject') ? 'qc_rejected' : (st.contains('review') ? 'in_review' : 'pending_qc')),
                  'assigned_to': assignedTo,
                };

                if (st.contains('approved')) fetchedApproved.add(formattedTicket);
                else if (st.contains('reject')) fetchedRejected.add(formattedTicket);
                else if (st.contains('review')) fetchedInReview.add(formattedTicket);
                else fetchedPending.add(formattedTicket);
              }
            }
          }
        } catch (err) {
          debugPrint('LocalStorage QC parse error: $err');
        }
      }

      if (mounted) {
        setState(() {
          _myTickets = fetchedPending;
          _inReviewTickets = fetchedInReview;
          _qcApprovedList = fetchedApproved;
          _qcRejectedList = fetchedRejected;

          _statistics['total_assigned'] = _myTickets.length + _inReviewTickets.length + _qcApprovedList.length + _qcRejectedList.length;
          _statistics['pending_review'] = _myTickets.length;
          _statistics['in_review'] = _inReviewTickets.length;
          _statistics['approved'] = _qcApprovedList.length;
          _statistics['rejected'] = _qcRejectedList.length;
          _statistics['completed_today'] = _qcApprovedList.length + _qcRejectedList.length;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitQCReview(Map<String, dynamic> item, bool isApproved) async {
    final ticketId = item['id'] ?? item['ticket_code'];
    final reason = _rejectReasonCtrl.text.trim();
    if (!isApproved && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a rejection reason feedback.')),
      );
      return;
    }

    final newStatus = isApproved ? 'qc_approved' : 'qc_rejected';

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/v1/qc-tickets/tickets/$ticketId/status');
      await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': newStatus,
          'reason': reason,
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    if (kIsWeb) {
      try {
        final raw = html.window.localStorage['platform_qc_submissions'];
        List<dynamic> list = [];
        if (raw != null) {
          list = jsonDecode(raw);
        }

        bool found = false;
        for (int i = 0; i < list.length; i++) {
          final idMatch = list[i]['id'] == ticketId ||
              list[i]['raw_id'] == ticketId ||
              list[i]['ticket_code'] == ticketId ||
              list[i]['title'] == item['video_title'] ||
              list[i]['title'] == item['title'];
          if (idMatch) {
            list[i]['status'] = newStatus;
            if (!isApproved) list[i]['reason'] = reason;
            found = true;
            break;
          }
        }

        if (!found) {
          list.insert(0, {
            'id': ticketId ?? 'VID-${DateTime.now().millisecondsSinceEpoch}',
            'raw_id': ticketId,
            'title': item['video_title'] ?? item['title'] ?? 'Candidate Dataset Recording',
            'candidateName': item['candidate_name'] ?? item['candidateName'] ?? 'Rahul Sharma (CAN-001)',
            'vendor': item['vendor_name'] ?? item['vendor'] ?? 'Acme Video Solutions',
            'duration': '${item['duration'] ?? 15} Mins',
            'score': 98,
            'status': newStatus,
            'reason': !isApproved ? reason : null,
            'assignedTo': 'QC Team Reviewer',
          });
        }

        html.window.localStorage['platform_qc_submissions'] = jsonEncode(list);

        // Save Candidate Notification
        final rawNotifs = html.window.localStorage['platform_candidate_notifications'];
        List<dynamic> notifList = [];
        if (rawNotifs != null) {
          notifList = jsonDecode(rawNotifs);
        }
        final notifTitle = isApproved ? '✓ QC Team Approved Your Video' : '✕ QC Team Rejected Your Video';
        final notifDesc = isApproved
            ? 'QC Team approved your video recording "${item['video_title'] ?? item['title'] ?? 'Video'}". It has been sent to Admin for final approval.'
            : 'QC Team rejected your video recording "${item['video_title'] ?? item['title'] ?? 'Video'}". Reason: $reason';
        
        notifList.insert(0, {
          'id': 'notif-qc-${DateTime.now().millisecondsSinceEpoch}',
          'title': notifTitle,
          'message': notifDesc,
          'desc': notifDesc,
          'time': 'Just now',
          'type': newStatus,
          'read': false,
        });
        html.window.localStorage['platform_candidate_notifications'] = jsonEncode(notifList);

        final bc = html.BroadcastChannel('platform_realtime_channel');
        bc.postMessage({'type': 'QC_STATUS_UPDATED', 'payload': list});
        bc.close();
      } catch (e) {
        debugPrint('QC submission error: $e');
      }
    }

    setState(() {
      _myTickets.removeWhere((i) => i['id'] == ticketId || i['ticket_code'] == ticketId);
      _inReviewTickets.removeWhere((i) => i['id'] == ticketId || i['ticket_code'] == ticketId);
      final updatedItem = Map<String, dynamic>.from(item);
      updatedItem['status'] = newStatus;
      if (!isApproved) updatedItem['reason'] = reason;

      if (isApproved) {
        _qcApprovedList.insert(0, updatedItem);
        _statistics['approved'] = (_statistics['approved'] ?? 0) + 1;
      } else {
        _qcRejectedList.insert(0, updatedItem);
        _statistics['rejected'] = (_statistics['rejected'] ?? 0) + 1;
      }

      _statistics['completed_today'] = (_statistics['completed_today'] ?? 0) + 1;
      _statistics['pending_review'] = _myTickets.length;
    });

    _rejectReasonCtrl.clear();
    if (mounted) {
      Navigator.pop(context); // Close review modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved ? '✅ QC Ticket Approved (Forwarded to Admin Sign-Off)' : '❌ QC Ticket Rejected with Feedback',
          ),
          backgroundColor: isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openQCInspectionModal(Map<String, dynamic> item) {
    _audioClarity = 4.5;
    _lightingQuality = 4.0;
    _framingScore = 5.0;
    _envMatchScore = 5.0;
    _rejectReasonCtrl.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'TICKET: ${item['ticket_code'] ?? item['id']}',
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['video_title'] ?? 'Video Inspection',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(Icons.person, item['candidate_name'] ?? 'Candidate'),
                      _buildInfoChip(Icons.store, item['vendor_name'] ?? 'Vendor'),
                      _buildInfoChip(Icons.work, item['project_id'] ?? 'PRJ-DEFAULT'),
                      _buildInfoChip(Icons.place, item['environment_tag'] ?? 'Environment'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Video Preview Placeholder Box
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, size: 54, color: Colors.white),
                            SizedBox(height: 6),
                            Text('Tap to Inspect High-Definition Video Clip', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '${item['duration'] ?? 30}s',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text('📊 QC 4-Tier Evaluation Sliders:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),

                  _buildRatingSlider('Audio Clarity', _audioClarity, (val) => modalSetState(() => _audioClarity = val)),
                  _buildRatingSlider('Lighting & Clarity', _lightingQuality, (val) => modalSetState(() => _lightingQuality = val)),
                  _buildRatingSlider('Subject Framing Score', _framingScore, (val) => modalSetState(() => _framingScore = val)),
                  _buildRatingSlider('Environment Tag Match', _envMatchScore, (val) => modalSetState(() => _envMatchScore = val)),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _rejectReasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason / QC Feedback (Required if Rejecting)',
                      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _submitQCReview(item, false),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444)),
                          label: const Text('QC Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _submitQCReview(item, true),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('QC Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRatingSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text('${value.toStringAsFixed(1)} / 5.0', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            thumbColor: const Color(0xFF8B5CF6),
            activeTrackColor: const Color(0xFF8B5CF6),
            inactiveTrackColor: const Color(0xFFE2E8F0),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: 1.0,
            max: 5.0,
            divisions: 8,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quality Control Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text('Least Workload Auto-Allocated Tickets', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: _fetchRealQCData,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8B5CF6)),
            tooltip: 'Refresh Tickets',
          ),
          IconButton(
            onPressed: () async {
              await AuthService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchRealQCData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reviewer Activity Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF8B5CF6), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reviewer Status: ACTIVE • Inactivity > 24h triggers automatic ticket reassignment',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6D28D9)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Statistics Metrics Grid
                Row(
                  children: [
                    _buildStatCard('Assigned', '${_statistics['total_assigned'] ?? 0}', const Color(0xFF8B5CF6), Icons.assignment_ind_rounded),
                    const SizedBox(width: 8),
                    _buildStatCard('Pending', '${_myTickets.length}', const Color(0xFFF59E0B), Icons.pending_actions_rounded),
                    const SizedBox(width: 8),
                    _buildStatCard('In Review', '${_inReviewTickets.length}', const Color(0xFF0EA5E9), Icons.rate_review_rounded),
                    const SizedBox(width: 8),
                    _buildStatCard('Today', '${_statistics['completed_today'] ?? 0}', const Color(0xFF10B981), Icons.today_rounded),
                  ],
                ),

                const SizedBox(height: 20),

                // Tab Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      _buildTabButton(0, 'My Tickets (${_myTickets.length})'),
                      _buildTabButton(1, 'In Review (${_inReviewTickets.length})'),
                      _buildTabButton(2, 'Approved (${_qcApprovedList.length})'),
                      _buildTabButton(3, 'Rejected (${_qcRejectedList.length})'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // List Items
                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else
                  _buildActiveTabList(),

                const SizedBox(height: 24),
                const PoweredByFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabList() {
    List<Map<String, dynamic>> targetList = [];
    if (_activeTab == 0) targetList = _myTickets;
    if (_activeTab == 1) targetList = _inReviewTickets;
    if (_activeTab == 2) targetList = _qcApprovedList;
    if (_activeTab == 3) targetList = _qcRejectedList;

    if (targetList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('No QC tickets found in this queue.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: targetList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final item = targetList[idx];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['ticket_code'] ?? item['id'] ?? 'TKT-000',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                      ),
                    ),
                    _buildStatusChip(item['status'] ?? 'pending_qc'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item['video_title'] ?? 'Video Clip Task',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(item['candidate_name'] ?? 'Candidate', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 12),
                    Icon(Icons.place_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(item['environment_tag'] ?? 'Environment', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                if (item['reason'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                    child: Text('Defect Reason: ${item['reason']}', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                  ),
                ],
                if (_activeTab == 0 || _activeTab == 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openQCInspectionModal(item),
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('Inspect & Review QC Ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = const Color(0xFFF59E0B);
    Color text = Colors.white;
    String label = 'Pending QC';

    if (status == 'in_review') {
      bg = const Color(0xFF0EA5E9);
      label = 'In Review';
    } else if (status == 'qc_approved') {
      bg = const Color(0xFF10B981);
      label = 'QC Approved';
    } else if (status == 'qc_rejected') {
      bg = const Color(0xFFEF4444);
      label = 'QC Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bg)),
    );
  }
}
