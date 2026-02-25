import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/ojt_service.dart';
import '../../services/auth_service.dart';
import '../../models/ojt_record.dart';
import '../../models/user.dart';

class CoordinatorOjtManagementScreen extends StatefulWidget {
  const CoordinatorOjtManagementScreen({super.key});

  @override
  State<CoordinatorOjtManagementScreen> createState() =>
      _CoordinatorOjtManagementScreenState();
}

class _CoordinatorOjtManagementScreenState
    extends State<CoordinatorOjtManagementScreen> {
  List<OjtRecord> _ojtRecords = [];
  bool _isLoading = true;
  String? _errorMessage;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadOjtRecords();
  }

  Future<void> _loadOjtRecords() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) {
        throw Exception('User not logged in');
      }

      final records = await OjtService.getOjtRecords(
          coordinatorId: currentUser!.userId);
      setState(() {
        _ojtRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateOjtRecordDialog() async {
    final formKey = GlobalKey<FormState>();
    final studentIdController = TextEditingController();
    final companyNameController = TextEditingController();
    final supervisorIdController = TextEditingController();
    final requiredHoursController = TextEditingController(text: '300');
    final companyAddressController = TextEditingController();
    final companyContactController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create OJT Record'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: studentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Student ID',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter student ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter company name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: supervisorIdController,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor ID',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter supervisor ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: requiredHoursController,
                    decoration: const InputDecoration(
                      labelText: 'Required Hours',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter required hours';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: companyAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Company Address (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: companyContactController,
                    decoration: const InputDecoration(
                      labelText: 'Company Contact (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(startDate != null
                        ? 'Start Date: ${_dateFormat.format(startDate!)}'
                        : 'Select Start Date'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() {
                          startDate = date;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text(endDate != null
                        ? 'End Date: ${_dateFormat.format(endDate!)}'
                        : 'Select End Date (Optional)'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() {
                          endDate = date;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && startDate != null) {
                  try {
                    final currentUser = await AuthService.getCurrentUser();
                    if (currentUser?.userId == null) {
                      throw Exception('User not logged in');
                    }

                    await OjtService.createOjtRecord(
                      studentId: int.parse(studentIdController.text),
                      companyName: companyNameController.text,
                      coordinatorId: currentUser!.userId!,
                      supervisorId: int.parse(supervisorIdController.text),
                      startDate: startDate,
                      endDate: endDate,
                      requiredHours: int.parse(requiredHoursController.text),
                      companyAddress: companyAddressController.text.isNotEmpty
                          ? companyAddressController.text
                          : null,
                      companyContact: companyContactController.text.isNotEmpty
                          ? companyContactController.text
                          : null,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('OJT record created successfully')),
                      );
                      _loadOjtRecords();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OJT Records Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateOjtRecordDialog,
            tooltip: 'Create New OJT Record',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOjtRecords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOjtRecords,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _ojtRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_outline,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No OJT records found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showCreateOjtRecordDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Create OJT Record'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOjtRecords,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ojtRecords.length,
                        itemBuilder: (context, index) {
                          final record = _ojtRecords[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Colors.deepPurple.withOpacity(0.1),
                                child: const Icon(Icons.work,
                                    color: Colors.deepPurple),
                              ),
                              title: Text(
                                record.studentName ?? 'Unknown Student',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Company: ${record.companyName ?? 'N/A'}'),
                                  Text('Status: ${record.status}'),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRow(
                                          'Student', record.studentName ?? 'N/A'),
                                      _buildInfoRow('Company',
                                          record.companyName ?? 'N/A'),
                                      if (record.companyAddress != null)
                                        _buildInfoRow('Address',
                                            record.companyAddress!),
                                      if (record.companyContact != null)
                                        _buildInfoRow('Contact',
                                            record.companyContact!),
                                      _buildInfoRow('Coordinator',
                                          record.coordinatorName ?? 'N/A'),
                                      _buildInfoRow('Supervisor',
                                          record.supervisorName ?? 'N/A'),
                                      if (record.startDate != null)
                                        _buildInfoRow('Start Date',
                                            _dateFormat.format(record.startDate!)),
                                      if (record.endDate != null)
                                        _buildInfoRow('End Date',
                                            _dateFormat.format(record.endDate!)),
                                      _buildInfoRow('Required Hours',
                                          '${record.requiredHours ?? 300} hours'),
                                      _buildInfoRow('Status', record.status),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

