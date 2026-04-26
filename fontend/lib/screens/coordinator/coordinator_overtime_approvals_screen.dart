import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/overtime_request.dart';
import '../../services/attendance_service.dart';
import '../../core/app_theme.dart';

class CoordinatorOvertimeApprovalsScreen extends StatefulWidget {
  const CoordinatorOvertimeApprovalsScreen({Key? key}) : super(key: key);

  @override
  State<CoordinatorOvertimeApprovalsScreen> createState() => _CoordinatorOvertimeApprovalsScreenState();
}

class _CoordinatorOvertimeApprovalsScreenState extends State<CoordinatorOvertimeApprovalsScreen> {
  List<OvertimeRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await AttendanceService.getSupervisorOvertimeRequests();
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateStatus(int requestId, String status, {String? remarks}) async {
    try {
      await AttendanceService.updateSupervisorOvertimeRequestStatus(
        requestId, status, coordinatorRemarks: remarks,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request $status successfully.'),
          backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
        ),
      );
      _fetchRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showActionDialog(OvertimeRequest req, String action) {
    final remarksController = TextEditingController();
    final bool isApprove = action == 'Approved';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isApprove ? 'Approve Overtime Request' : 'Reject Overtime Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isApprove
                  ? 'You are about to approve this overtime request for ${req.studentNames.length} student(s).'
                  : 'You are about to reject this request. Please provide a reason.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                labelText: isApprove ? 'Remarks (optional)' : 'Reason for rejection',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!isApprove && remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for rejection.')),
                );
                return;
              }
              Navigator.pop(ctx);
              _updateStatus(req.requestId, action, remarks: remarksController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isApprove ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((r) => r.status == 'Pending').toList();
    final history = _requests.where((r) => r.status != 'Pending').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Overtime Approvals'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'History (${history.length})'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildRequestList(pending, showActions: true),
                  _buildRequestList(history, showActions: false),
                ],
              ),
      ),
    );
  }

  Widget _buildRequestList(List<OvertimeRequest> list, {required bool showActions}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(showActions ? Icons.inbox_rounded : Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              showActions ? 'No pending overtime requests.' : 'No overtime request history.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildRequestCard(list[index], showActions: showActions),
      ),
    );
  }

  Widget _buildRequestCard(OvertimeRequest req, {required bool showActions}) {
    Color statusColor;
    if (req.status == 'Approved') {
      statusColor = Colors.green;
    } else if (req.status == 'Rejected') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.person_pin, size: 18, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                  Text('From: ${req.supervisorName ?? "Supervisor"}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(req.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Date: ${DateFormat('MMMM d, yyyy').format(req.date)}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ]),
            const Divider(height: 20),

            // Student List
            Text('Students Requested:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: req.studentNames.map((s) => Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text(s.fullName[0].toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.teal.shade800)),
                ),
                label: Text(s.fullName, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey.shade50,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
            const SizedBox(height: 16),

            // Formal Letter
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text('Formal Letter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(req.formalLetter, style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),

            // Coordinator Remarks (if any)
            if (req.coordinatorRemarks != null && req.coordinatorRemarks!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Your remarks: ${req.coordinatorRemarks}', style: TextStyle(fontSize: 13, color: Colors.blue.shade900)),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showActionDialog(req, 'Rejected'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showActionDialog(req, 'Approved'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
