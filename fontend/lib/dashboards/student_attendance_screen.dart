import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final picker = ImagePicker();
  late SignatureController _signatureController;

  File? _attendanceImage;
  Map<String, String> timeLogs = {
    "Morning In": "",
    "Morning Out": "",
    "Afternoon In": "",
    "Afternoon Out": "",
    "Overtime In": "",
    "Overtime Out": "",
  };

  // ✅ Overtime is optional — we check only the first 4
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
    _loadAttendanceData();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  // ---------------- Load & Save Attendance ----------------
  Future<void> _loadAttendanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLogs = prefs.getStringList('dtr_logs');
    if (savedLogs != null && savedLogs.length == 6) {
      setState(() {
        timeLogs["Morning In"] = savedLogs[0];
        timeLogs["Morning Out"] = savedLogs[1];
        timeLogs["Afternoon In"] = savedLogs[2];
        timeLogs["Afternoon Out"] = savedLogs[3];
        timeLogs["Overtime In"] = savedLogs[4];
        timeLogs["Overtime Out"] = savedLogs[5];
      });
    }
  }

  Future<void> _saveAttendanceData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dtr_logs', [
      timeLogs["Morning In"]!,
      timeLogs["Morning Out"]!,
      timeLogs["Afternoon In"]!,
      timeLogs["Afternoon Out"]!,
      timeLogs["Overtime In"]!,
      timeLogs["Overtime Out"]!,
    ]);
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
    bool granted = await _requestCameraPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission required.")),
      );
      return;
    }

    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 80);

      if (image != null) {
        String timeNow = DateFormat('hh:mm a').format(DateTime.now());

        setState(() {
          _attendanceImage = File(image.path);
          timeLogs[label] = timeNow;
        });

        await _saveAttendanceData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ $label recorded at $timeNow")),
        );

        // ✅ Show signature pad once Morning & Afternoon are complete
        if (isComplete) {
          Future.delayed(const Duration(milliseconds: 400), () {
            _showSignatureDialog();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Camera error: $e")),
      );
    }
  }

  // ---------------- Signature Dialog ----------------
  void _showSignatureDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("🖋 Certified By"),
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
              child: const Text("Clear")),
          ElevatedButton(
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
            child: const Text("Save Signature"),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final now = DateFormat('MMM d, yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("🕒 Daily Time Record"),
        backgroundColor: Colors.orange,
      ),
      body: ListView(
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

          // Buttons
          ...timeLogs.keys.map((label) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: timeLogs[label]!.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: Text(
                    timeLogs[label]!.isNotEmpty
                        ? "$label - Done"
                        : "Record $label",
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: timeLogs[label]!.isEmpty
                      ? () => _handleAttendance(label)
                      : null,
                ),
              )),

          const SizedBox(height: 30),

          if (_attendanceImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _attendanceImage!,
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
