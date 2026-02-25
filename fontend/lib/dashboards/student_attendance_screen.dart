import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../core/config.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/ojt_sites_service.dart';
import '../services/location_service.dart';
import '../services/geofence_service.dart';
import '../services/location_security_service.dart';
import '../core/attendance_constants.dart';
import '../models/attendance.dart';
import '../utils/web_image_picker.dart';

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
  String? _companyName; // For geofence site lookup
  
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

  // ---------------- Check and Reset Daily State ----------------
  /// Checks if it's a new day and resets all daily attendance state
  /// This ensures students start fresh each day
  Future<void> _checkAndResetDailyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAttendanceDate = prefs.getString('last_attendance_date');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Always reset time logs first, then check if we need to clear other state
      bool isNewDay = lastAttendanceDate != today;
      
      // Reset in-memory state - always clear time logs to start fresh
      if (mounted) {
        setState(() {
          _attendanceImageBytes = null;
          // Always reset all time logs to empty - will be populated from today's attendance if it exists
          timeLogs = {
            "Morning In": "",
            "Morning Out": "",
            "Afternoon In": "",
            "Afternoon Out": "",
            "Overtime In": "",
            "Overtime Out": "",
          };
          // Only clear today's attendance if it's a new day
          if (isNewDay) {
            _todayAttendance = null;
          }
        });
      }

      // If it's a new day, clear stored preferences
      if (isNewDay) {
        // Clear attendance image
        await prefs.remove('attendance_image');
        await prefs.remove('attendance_image_base64');
        await prefs.setString('last_attendance_image_date', today);
        
        // Clear time-in status
        await prefs.remove('is_timed_in');
        await prefs.remove('last_action_time');
        
        // Update the last attendance date
        await prefs.setString('last_attendance_date', today);
      }
    } catch (e) {
      // Silently handle errors - don't block initialization
      print('Error checking/resetting daily state: $e');
    }
  }

  // ---------------- Initialize & Load Attendance ----------------
  Future<void> _initializeData() async {
    try {
      setState(() {
        _isInitializing = true;
      });

      // Check if it's a new day and reset all daily state if needed
      await _checkAndResetDailyState();

      // Get current user
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      _studentId = user.userId;

      // Get OJT record for this student (for segment logging and geofence site lookup)
      try {
        final ojtRecords = await OjtService.getOjtRecords(studentId: _studentId);
        if (ojtRecords.isNotEmpty) {
          _ojtRecordId = ojtRecords.first.recordId;
          _companyName = ojtRecords.first.companyName;
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
      // First check if it's a new day and reset if needed
      await _checkAndResetDailyState();
      
      // Get today's date to verify attendance is from today
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final attendance = await AttendanceService.getTodayAttendance(_studentId!);
      
      if (mounted) {
        setState(() {
          // Only set today's attendance if it exists and is from today
          if (attendance != null) {
            // Verify the attendance date matches today
            final attendanceDate = attendance.date != null 
                ? DateFormat('yyyy-MM-dd').format(attendance.date!)
                : null;
            
            if (attendanceDate == today) {
              // Only populate time logs if attendance exists for TODAY
              _todayAttendance = attendance;
              // Convert database time format (HH:MM:SS) to display format (hh:mm a)
              timeLogs["Morning In"] = _formatTimeForDisplay(attendance.morningIn);
              timeLogs["Morning Out"] = _formatTimeForDisplay(attendance.morningOut);
              timeLogs["Afternoon In"] = _formatTimeForDisplay(attendance.afternoonIn);
              timeLogs["Afternoon Out"] = _formatTimeForDisplay(attendance.afternoonOut);
              timeLogs["Overtime In"] = _formatTimeForDisplay(attendance.overtimeIn);
              timeLogs["Overtime Out"] = _formatTimeForDisplay(attendance.overtimeOut);
            } else {
              // Attendance is from a different day - clear it
              _todayAttendance = null;
              timeLogs = {
                "Morning In": "",
                "Morning Out": "",
                "Afternoon In": "",
                "Afternoon Out": "",
                "Overtime In": "",
                "Overtime Out": "",
              };
            }
          } else {
            // No attendance for today - ensure time logs are empty
            _todayAttendance = null;
            timeLogs = {
              "Morning In": "",
              "Morning Out": "",
              "Afternoon In": "",
              "Afternoon Out": "",
              "Overtime In": "",
              "Overtime Out": "",
            };
          }
        });
      }
    } catch (e) {
      print('Error loading today attendance: $e');
      // Don't show error to user, just log it
      // But ensure time logs are reset on error
      if (mounted) {
        setState(() {
          timeLogs = {
            "Morning In": "",
            "Morning Out": "",
            "Afternoon In": "",
            "Afternoon Out": "",
            "Overtime In": "",
            "Overtime Out": "",
          };
        });
      }
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
    try {
      var status = await Permission.camera.status;
      if (status.isGranted) return true;
      
      status = await Permission.camera.request();
      if (status.isGranted) return true;
      
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Camera Permission Required"),
              content: const Text(
                "Camera permission is required to record attendance. "
                "Please enable it in app settings.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text("Open Settings"),
                ),
              ],
            ),
          );
        }
      }
      return false;
    } catch (e) {
      print('Error requesting camera permission: $e');
      return false;
    }
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

    // --- Geofence + location trust (optional; backward compatible when no position/sites) ---
    double? checkinLat;
    double? checkinLng;
    double? checkoutLat;
    double? checkoutLng;
    double? accuracyM;
    double? distanceM;
    bool? insideGeofence;
    int? trustScore;
    List<String>? trustFlags;

    if (!kIsWeb) {
      // For time-out use current position as checkout; for time-in as checkin
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        // Fetch geofence site for this student's company
        final sites = await OjtSitesService.getSitesByCompanyName(_companyName);
        if (sites.isNotEmpty && GeofenceConfig.enforceGeofence) {
          final geofence = GeofenceService.check(
            sites.first,
            position.latitude,
            position.longitude,
          );
          if (!geofence.inside) {
            if (GeofenceConfig.blockOutsideGeofence) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Outside work site'),
                    content: Text(
                      'You are ${geofence.distanceMeters.toStringAsFixed(0)} m away from the site. '
                      'Please be within the designated area to check in.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
              return;
            }
            insideGeofence = false;
            distanceM = geofence.distanceMeters;
          } else {
            insideGeofence = true;
            distanceM = geofence.distanceMeters;
          }
        }
        // Trust evaluation (mock, teleport, low accuracy)
        final trust = await LocationSecurityService.evaluate(position);
        if (GeofenceConfig.blockIfMockLocation &&
            (trust.evidence.isMock == true)) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Location not allowed'),
                content: const Text(
                  'Mock or simulated location is not allowed for attendance.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
        if (isTimeIn) {
          checkinLat = position.latitude;
          checkinLng = position.longitude;
        } else {
          checkoutLat = position.latitude;
          checkoutLng = position.longitude;
        }
        accuracyM = position.accuracy > 0 ? position.accuracy : null;
        trustScore = trust.result.score;
        trustFlags =
            trust.result.reasons.isEmpty ? null : trust.result.reasons;
      }
    }

    // Request camera permission and open camera
    ImageSource imageSource = ImageSource.camera;
    
    if (kIsWeb) {
      // Offer choice between webcam capture and file upload on web
      final choice = await _showWebImageSourceDialog();
      if (choice == null) {
        return;
      }
      imageSource = choice;
      if (imageSource == ImageSource.gallery) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📁 Please select an image from your files."),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📷 Using your webcam for capture."),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // On mobile, request camera permission first
      setState(() {
        _isLoading = true;
      });
      
      bool granted = await _requestCameraPermission();
      
      if (!granted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Camera permission is required to record attendance"),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    try {
      Uint8List? imageBytes;

      if (kIsWeb) {
        imageBytes = await pickWebImageBytes(
          useCamera: imageSource == ImageSource.camera,
        );
      } else {
        // Open camera/gallery to capture image on mobile
        final XFile? image = await picker.pickImage(
          source: imageSource,
          imageQuality: 85, // Good quality for database storage
          preferredCameraDevice: CameraDevice.front, // Use front camera for selfie
        );

        if (image == null) {
          // User cancelled camera/gallery
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("📷 No image selected. Attendance not recorded."),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        imageBytes = await image.readAsBytes();
      }

      if (imageBytes == null) {
        if (GeofenceConfig.requirePhotoForAttendance &&
            !GeofenceConfig.allowNoPhotoFallback) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "⚠️ Photo is required for attendance. Please try again."),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Unable to capture image. Please try again."),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Show preview dialog before saving to database
      final shouldSave = await _showImagePreviewDialog(imageBytes, label);
      if (!shouldSave) {
        // User wants to retake the photo
        return;
      }

      // Show loading state
      if (mounted) {
        setState(() {
          _isLoading = true;
          _attendanceImageBytes = imageBytes;
        });
      }

      try {
        // Encode image to base64 for database storage
        final base64Image = base64Encode(imageBytes);
        
        // Get current date in YYYY-MM-DD format
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        // Save the attendance date to SharedPreferences for daily reset check
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_attendance_date', today);
        await prefs.setString('last_attendance_image_date', today);
        if (kIsWeb) {
          await prefs.setString('attendance_image_base64', base64Image);
        }
        
        Attendance? updatedAttendance;
        
        // Save to database based on time in/out
        if (isTimeIn) {
          updatedAttendance = await AttendanceService.logTimeIn(
            studentId: _studentId!,
            ojtRecordId: _ojtRecordId,
            segment: segment,
            date: today,
            attendanceImage: base64Image,
            checkinLat: checkinLat,
            checkinLng: checkinLng,
            accuracyM: accuracyM,
            distanceM: distanceM,
            insideGeofence: insideGeofence,
            trustScore: trustScore,
            trustFlags: trustFlags,
          );
        } else {
          updatedAttendance = await AttendanceService.logTimeOut(
            studentId: _studentId!,
            segment: segment,
            date: today,
            attendanceId: _todayAttendance?.attendanceId,
            attendanceImage: base64Image,
            checkinLat: checkinLat,
            checkinLng: checkinLng,
            checkoutLat: checkoutLat,
            checkoutLng: checkoutLng,
            accuracyM: accuracyM,
            distanceM: distanceM,
            insideGeofence: insideGeofence,
            trustScore: trustScore,
            trustFlags: trustFlags,
          );
        }

        // Update local state with the response from database
        if (updatedAttendance != null && mounted) {
          final attendance = updatedAttendance;
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

        // Show success message
        String timeNow = DateFormat('hh:mm a').format(DateTime.now());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ $label recorded at $timeNow\n📸 Image saved to database"),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }

        // If all required segments are complete, show signature dialog
        if (isComplete && mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showSignatureDialog();
            }
          });
        }
      } catch (e) {
        // Error saving to database
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("⚠️ Failed to save attendance to database: $e"),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red,
            ),
          );
          // Revert image if save failed
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
    } catch (e) {
      // Camera/gallery error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Camera error: $e\nPlease try again or check camera permissions"),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<ImageSource?> _showWebImageSourceDialog() async {
    if (!mounted) return null;
    return showDialog<ImageSource>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Choose Image Source"),
          content: const Text(
            "Select how you'd like to capture your attendance photo.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: const Text("Upload Photo"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              icon: const Icon(Icons.videocam),
              label: const Text("Use Camera"),
            ),
          ],
        );
      },
    );
  }

  // ---------------- Image Preview Dialog ----------------
  Future<bool> _showImagePreviewDialog(Uint8List imageBytes, String label) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.camera_alt, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Confirm $label Photo",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Review your photo before saving to database",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Is this photo correct?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.camera_alt),
            label: const Text("Retake Photo"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle),
            label: const Text("Save to Database"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;
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

          // Attendance buttons with camera icon
          ...timeLogs.keys.map((label) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: timeLogs[label]!.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                    minimumSize: const Size(double.infinity, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    timeLogs[label]!.isNotEmpty
                        ? Icons.check_circle
                        : Icons.camera_alt,
                    size: 24,
                    color: Colors.white,
                  ),
                  label: Text(
                    timeLogs[label]!.isNotEmpty
                        ? "$label - Recorded ✓"
                        : kIsWeb 
                            ? "Select Photo for $label"
                            : "Open Camera for $label",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
