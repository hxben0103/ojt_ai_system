import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../core/attendance_constants.dart';
import '../models/attendance.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final picker = ImagePicker();
  late SignatureController _signatureController;

  Uint8List? _attendanceImageBytes;
  bool _isLoading = false;
  bool _isInitializing = true;
  Attendance? _todayAttendance;
  int? _studentId;
  int? _ojtRecordId;
  
  // Map segment constants to display labels
  final Map<String, String> _segmentToLabel = {
    AttendanceSegments.morningIn: "Morning In",
    AttendanceSegments.morningOut: "Morning Out",
    AttendanceSegments.afternoonIn: "Afternoon In",
    AttendanceSegments.afternoonOut: "Afternoon Out",
    AttendanceSegments.overtimeIn: "Overtime In",
    AttendanceSegments.overtimeOut: "Overtime Out",
  };

  Map<String, String> timeLogs = {
    "Morning In": "",
    "Morning Out": "",
    "Afternoon In": "",
    "Afternoon Out": "",
    "Overtime In": "",
    "Overtime Out": "",
  };

  bool get isComplete =>
      timeLogs["Morning In"]!.isNotEmpty &&
      timeLogs["Morning Out"]!.isNotEmpty &&
      timeLogs["Afternoon In"]!.isNotEmpty &&
      timeLogs["Afternoon Out"]!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _initializeData();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  // ---------------- Initialize & Load Attendance ----------------
  Future<void> _initializeData() async {
    try {
      setState(() {
        _isInitializing = true;
      });

      // Get current user
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      _studentId = user.userId;

      // Get OJT record for this student
      try {
        final ojtRecords = await OjtService.getOjtRecords(studentId: _studentId);
        if (ojtRecords.isNotEmpty) {
          _ojtRecordId = ojtRecords.first.recordId;
        }
      } catch (e) {
        // OJT record not found, but continue anyway
        print('Warning: Could not fetch OJT record: $e');
      }

      // Load today's attendance
      await _loadTodayAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _loadTodayAttendance() async {
    if (_studentId == null) return;

    try {
      final attendance = await AttendanceService.getTodayAttendance(_studentId!);
      
      if (mounted) {
        setState(() {
          _todayAttendance = attendance;
          if (attendance != null) {
            // Convert database time format (HH:MM:SS) to display format (hh:mm a)
            timeLogs["Morning In"] = _formatTimeForDisplay(attendance.morningIn);
            timeLogs["Morning Out"] = _formatTimeForDisplay(attendance.morningOut);
            timeLogs["Afternoon In"] = _formatTimeForDisplay(attendance.afternoonIn);
            timeLogs["Afternoon Out"] = _formatTimeForDisplay(attendance.afternoonOut);
            timeLogs["Overtime In"] = _formatTimeForDisplay(attendance.overtimeIn);
            timeLogs["Overtime Out"] = _formatTimeForDisplay(attendance.overtimeOut);
          }
        });
      }
    } catch (e) {
      print('Error loading today attendance: $e');
      // Don't show error to user, just log it
    }
  }

  String _formatTimeForDisplay(String? time) {
    if (time == null || time.isEmpty) return "";
    
    try {
      // Parse HH:MM:SS or HH:MM format
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return time;
  }

  // ---------------- Camera & Attendance ----------------
  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) openAppSettings();
    return false;
  }

  Future<void> _handleAttendance(String label) async {
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    // Find segment constant for this label
    String? segment;
    bool isTimeIn = false;
    
    for (var entry in _segmentToLabel.entries) {
      if (entry.value == label) {
        segment = entry.key;
        isTimeIn = AttendanceSegments.isTimeIn(segment);
        break;
      }
    }

    if (segment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid attendance label: $label")),
      );
      return;
    }

    // Check if already logged
    if (timeLogs[label]!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$label already recorded")),
      );
      return;
    }

    // On web, camera is not available, use gallery instead
    ImageSource imageSource = ImageSource.camera;
    if (kIsWeb) {
      imageSource = ImageSource.gallery;
    } else {
      bool granted = await _requestCameraPermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission required.")),
        );
        return;
      }
    }

    try {
      final XFile? image =
          await picker.pickImage(source: imageSource, imageQuality: 80);

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        setState(() {
          _isLoading = true;
          _attendanceImageBytes = imageBytes;
        });

        try {
          // Get current date
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          
          Attendance? updatedAttendance;
          
          if (isTimeIn) {
            updatedAttendance = await AttendanceService.logTimeIn(
              studentId: _studentId!,
              ojtRecordId: _ojtRecordId,
              segment: segment,
              date: today,
            );
          } else {
            updatedAttendance = await AttendanceService.logTimeOut(
              studentId: _studentId!,
              segment: segment,
              date: today,
              attendanceId: _todayAttendance?.attendanceId,
            );
          }

          // Update local state with the response
          if (updatedAttendance != null) {
            final attendance = updatedAttendance; // Store in non-nullable variable
            setState(() {
              _todayAttendance = attendance;
              timeLogs[label] = _formatTimeForDisplay(
                isTimeIn
                    ? (segment == AttendanceSegments.morningIn
                        ? attendance.morningIn
                        : segment == AttendanceSegments.afternoonIn
                            ? attendance.afternoonIn
                            : attendance.overtimeIn)
                    : (segment == AttendanceSegments.morningOut
                        ? attendance.morningOut
                        : segment == AttendanceSegments.afternoonOut
                            ? attendance.afternoonOut
                            : attendance.overtimeOut),
              );
            });
          }

          String timeNow = DateFormat('hh:mm a').format(DateTime.now());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ $label recorded at $timeNow")),
          );

          if (isComplete) {
            Future.delayed(const Duration(milliseconds: 400), () {
              _showSignatureDialog();
            });
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ Failed to save attendance: $e")),
          );
          // Revert image if save failed
          if (mounted) {
            setState(() {
              _attendanceImageBytes = null;
            });
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Camera error: $e")),
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------- Signature Dialog ----------------
  void _showSignatureDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Image.network(
              "https://cdn-icons-png.flaticon.com/512/1157/1157089.png",
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            const Text("Certified By"),
          ],
        ),
        content: SizedBox(
          height: 200,
          child: Signature(
            controller: _signatureController,
            backgroundColor: Colors.grey[200]!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _signatureController.clear();
            },
            child: const Text("Clear"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final signature = await _signatureController.toPngBytes();
              if (signature != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("✅ Signature saved successfully!")),
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: Image.network(
              "https://cdn-icons-png.flaticon.com/512/1828/1828640.png",
              width: 20,
              height: 20,
              color: Colors.white,
            ),
            label: const Text("Save Signature"),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final now = DateFormat('MMM d, yyyy').format(DateTime.now());

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.network(
                "https://cdn-icons-png.flaticon.com/512/2910/2910768.png",
                width: 26,
                height: 26,
              ),
              const SizedBox(width: 8),
              const Text("Daily Time Record"),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.network(
              "https://cdn-icons-png.flaticon.com/512/2910/2910768.png",
              width: 26,
              height: 26,
            ),
            const SizedBox(width: 8),
            const Text("Daily Time Record"),
          ],
        ),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadTodayAttendance();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date + Table
          Card(
            elevation: 5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("Date: $now",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Table(
                    border: TableBorder.all(color: Colors.grey),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                    },
                    children: [
                      _buildTableRow("Morning In", timeLogs["Morning In"]),
                      _buildTableRow("Morning Out", timeLogs["Morning Out"]),
                      _buildTableRow("Afternoon In", timeLogs["Afternoon In"]),
                      _buildTableRow(
                          "Afternoon Out", timeLogs["Afternoon Out"]),
                      _buildTableRow("Overtime In", timeLogs["Overtime In"]),
                      _buildTableRow("Overtime Out", timeLogs["Overtime Out"]),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons with network icons
          ...timeLogs.keys.map((label) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: timeLogs[label]!.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: Image.network(
                    "https://cdn-icons-png.flaticon.com/512/1047/1047711.png",
                    width: 22,
                    height: 22,
                    color: Colors.white,
                  ),
                  label: Text(
                    timeLogs[label]!.isNotEmpty
                        ? "$label - Done"
                        : "Record $label",
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: (_isLoading || timeLogs[label]!.isNotEmpty)
                      ? null
                      : () => _handleAttendance(label),
                ),
              )),

          const SizedBox(height: 30),

          if (_attendanceImageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _attendanceImageBytes!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String? time) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(time ?? "",
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ),
      ],
    );
  }
}
