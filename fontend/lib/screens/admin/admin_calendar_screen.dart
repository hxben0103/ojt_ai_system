import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/calendar_service.dart';
import '../../core/app_theme.dart';

class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final events = await CalendarService.getEvents();
      setState(() { _events = events; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return _dateFormat.format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  Color _eventColor(String? type) {
    switch (type) {
      case 'holiday': return const Color(0xFFE53935); // Red
      case 'exam_week': return const Color(0xFFFF8F00); // Amber
      case 'suspension': return const Color(0xFF6A1B9A); // Purple
      default: return const Color(0xFF1976D2); // Blue
    }
  }

  IconData _eventIcon(String? type) {
    switch (type) {
      case 'holiday': return Icons.celebration_rounded;
      case 'exam_week': return Icons.quiz_rounded;
      case 'suspension': return Icons.warning_rounded;
      default: return Icons.event_rounded;
    }
  }

  String _eventLabel(String? type) {
    switch (type) {
      case 'holiday': return 'Holiday';
      case 'exam_week': return 'Exam Week';
      case 'suspension': return 'Suspension';
      default: return 'Event';
    }
  }

  Future<void> _addEvent() async {
    String title = '';
    String eventType = 'holiday';
    DateTimeRange? dateRange;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Calendar Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'e.g. Midterm Exams',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: eventType,
                    decoration: const InputDecoration(
                      labelText: 'Event Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'holiday', child: Text('🎉 Holiday')),
                      DropdownMenuItem(value: 'exam_week', child: Text('📝 Exam Week')),
                      DropdownMenuItem(value: 'suspension', child: Text('⚠️ Suspension')),
                    ],
                    onChanged: (v) => setDialogState(() => eventType = v ?? 'holiday'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                        initialDateRange: dateRange,
                      );
                      if (picked != null) {
                        setDialogState(() => dateRange = picked);
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      dateRange != null
                          ? '${_dateFormat.format(dateRange!.start)} — ${_dateFormat.format(dateRange!.end)}'
                          : 'Select Date Range',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: title.isNotEmpty && dateRange != null
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminPrimary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Event'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && title.isNotEmpty && dateRange != null) {
      try {
        await CalendarService.createEvent(
          title: title,
          eventType: eventType,
          startDate: DateFormat('yyyy-MM-dd').format(dateRange!.start),
          endDate: DateFormat('yyyy-MM-dd').format(dateRange!.end),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event added successfully'), backgroundColor: Colors.green),
          );
        }
        await _loadEvents();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add event: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteEvent(int eventId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await CalendarService.deleteEvent(eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.orange),
          );
        }
        await _loadEvents();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('University Calendar'),
        backgroundColor: AppTheme.adminPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEvent,
        backgroundColor: AppTheme.adminPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadEvents, child: const Text('Retry')),
                    ],
                  ),
                )
              : _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No calendar events', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final type = event['event_type'] as String?;
                        final color = _eventColor(type);
                        final startDate = _formatDate(event['start_date']);
                        final endDate = _formatDate(event['end_date']);
                        final isRecurring = event['is_recurring'] == true;
                        final isSameDay = startDate == endDate;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: color.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_eventIcon(type), color: color, size: 24),
                            ),
                            title: Text(
                              event['title'] ?? 'Untitled',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  isSameDay ? startDate : '$startDate — $endDate',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _eventLabel(type),
                                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (isRecurring) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.repeat, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 2),
                                      Text('Recurring', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteEvent(
                                event['id'] as int,
                                event['title'] as String? ?? '',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

