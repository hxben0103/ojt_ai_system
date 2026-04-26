import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/overtime_request.dart';
import '../../models/ojt_record.dart';
import '../../services/attendance_service.dart';
import '../../providers/supervisor_provider.dart';
import '../../core/app_theme.dart';

class SupervisorOvertimeRequestsScreen extends StatefulWidget {
  const SupervisorOvertimeRequestsScreen({Key? key}) : super(key: key);

  @override
  State<SupervisorOvertimeRequestsScreen> createState() => _SupervisorOvertimeRequestsScreenState();
}

class _SupervisorOvertimeRequestsScreenState extends State<SupervisorOvertimeRequestsScreen> {
  // --- Form state ---
  DateTime _selectedDate = DateTime.now();
  final Set<int> _selectedStudentIds = {};
  final TextEditingController _letterController = TextEditingController();
  bool _isSubmitting = false;

  // --- History state ---
  List<OvertimeRequest> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _letterController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final requests = await AttendanceService.getSupervisorOvertimeRequests();
      setState(() {
        _history = requests;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_letterController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a formal letter.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AttendanceService.submitSupervisorOvertimeRequest(
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        studentIds: _selectedStudentIds.toList(),
        formalLetter: _letterController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Overtime request submitted to coordinator.'), backgroundColor: Colors.green),
      );
      _letterController.clear();
      _selectedStudentIds.clear();
      _fetchHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Overtime Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'New Request'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFormTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTab() {
    final students = context.watch<SupervisorProvider>().assignedStudents;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Date Picker ---
          Text('Select Date', style: AppTheme.heading3),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('MMMM d, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16)),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Student Selection ---
          Text('Select Students for Overtime', style: AppTheme.heading3),
          const SizedBox(height: 4),
          Text('Tap to select/deselect students', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No assigned students found.'),
            )
          else
            ...students.map((record) => _buildStudentCheckbox(record)),
          const SizedBox(height: 24),

          // --- Formal Letter ---
          Text('Formal Request Letter', style: AppTheme.heading3),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _letterController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Dear Coordinator,\n\nI am writing to formally request overtime approval for the following students on the specified date...\n\nRespectfully,\n[Your Name]',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Submit Button ---
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit to Coordinator', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStudentCheckbox(OjtRecord record) {
    final isSelected = _selectedStudentIds.contains(record.studentId);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? Colors.teal : Colors.grey.shade200, width: isSelected ? 2 : 1),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _selectedStudentIds.add(record.studentId);
            } else {
              _selectedStudentIds.remove(record.studentId);
            }
          });
        },
        activeColor: Colors.teal,
        title: Text(record.studentName ?? 'Student #${record.studentId}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(record.companyName ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        secondary: CircleAvatar(
          backgroundColor: isSelected ? Colors.teal.withOpacity(0.1) : Colors.grey.shade100,
          child: Text(
            (record.studentName ?? 'S')[0].toUpperCase(),
            style: TextStyle(color: isSelected ? Colors.teal : Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No overtime requests submitted yet.', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final req = _history[index];
          return _buildHistoryCard(req);
        },
      ),
    );
  }

  Widget _buildHistoryCard(OvertimeRequest req) {
    Color statusColor;
    IconData statusIcon;
    if (req.status == 'Approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (req.status == 'Rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(DateFormat('MMMM d, yyyy').format(req.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(req.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text('Students:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: req.studentNames.map((s) => Chip(
                label: Text(s.fullName, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.teal.withOpacity(0.08),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
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
                      child: Text(
                        'Coordinator: ${req.coordinatorRemarks}',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
