import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
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
import '../models/geofence_site.dart';
import '../services/location_service.dart';
import '../services/geofence_service.dart';
import '../services/location_security_service.dart';
import '../core/attendance_constants.dart';
import '../models/attendance.dart';
import '../utils/web_image_picker.dart';
import '../core/app_theme.dart';
import '../widgets/geofence_verification_panel.dart';
import '../widgets/attendance_integrity_row.dart';
import '../widgets/attendance/attendance_summary_card.dart';
import '../widgets/attendance/geofence_status_panel.dart';
import '../widgets/attendance/attendance_photo_evidence.dart';
import '../../widgets/restricted_access_screen.dart';

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
  List<Attendance> _attendanceHistory = [];
  int? _studentId;
  int? _ojtRecordId;
  String? _companyName; // For geofence site lookup
  String? _companyAddress; // For display
  bool _canPerformOjtActions = false; // Restrict UI access flag

  // Geofence/Location details for persistent display
  String? _siteName;
  String? _siteAddress;
  double? _distanceToSite;
  double? _gpsAccuracy;
  bool? _isInsideGeofence;
  int? _lastTrustScore;
  double? _currentLat;
  double? _currentLng;
  
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
      _todayAttendance?.afternoonOut != null ||
      (_todayAttendance?.overtimeOut != null) ||
      (timeLogs["Afternoon Out"]?.isNotEmpty ?? false);

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
      print('🔍 [Attendance] _checkAndResetDailyState: lastDate=$lastAttendanceDate, today=$today');

      // Always reset time logs first, then check if we need to clear other state
      bool isNewDay = lastAttendanceDate != today;
      print('🔍 [Attendance] isNewDay: $isNewDay');
      
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

      Future<void> _checkOjtStatus() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user?.userId != null) {
        // ✅ COORDINATOR BYPASS
        if (user!.role.toLowerCase().contains('coordinator')) {
          if (mounted) {
            setState(() {
              _canPerformOjtActions = true;
              _isLoading = false;
            });
          }
          return;
        }

        final status = await OjtService.getStudentStatus(user.userId!);
        if (mounted) {
          setState(() {
            _canPerformOjtActions = status['can_perform_ojt_actions'] == true;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

      // Get current user
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      _studentId = user.userId;

      // Get OJT record for this student (for segment logging and geofence site lookup)
      try {
        final userRole = user.role.toLowerCase();
        // ✅ COORDINATOR BYPASS: Allow access to the UI even if they don't have a personal OJT record
        if (userRole.contains('coordinator')) {
           _canPerformOjtActions = true;
           // If we are inspecting a specific student, we should ideally fetch THEIR record,
           // but for now, we just bypass the block.
        } else {
          final ojtRecords = await OjtService.getOjtRecords(studentId: _studentId);
          
          // Ensure student has an active/ongoing record with assigned coordinator/supervisor
          final activeRecord = ojtRecords.where((r) => 
              (r.status == 'Active' || r.status == 'Ongoing') && 
              r.coordinatorId != null && 
              r.supervisorId != null).firstOrNull;

          if (activeRecord != null) {
            _ojtRecordId = activeRecord.recordId;
            _companyName = activeRecord.companyName;
            _companyAddress = activeRecord.companyAddress;
            _canPerformOjtActions = true;
          } else {
            _canPerformOjtActions = false;
          }
        }
      } catch (e) {
        // OJT record not found, but continue anyway
        print('Warning: Could not fetch OJT record: $e');
        _canPerformOjtActions = user.role.toLowerCase().contains('coordinator');
      }

      // Load today's attendance and history
      await _loadTodayAttendance();
      await _fetchAttendanceHistory();
      
      // Attempt to get current location for the persistent panel (non-blocking)
      _updateLocationSilently();
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
      print('🔍 [Attendance] _loadTodayAttendance: fetching for student $_studentId, date $today');
      
      final attendance = await AttendanceService.getTodayAttendance(_studentId!, date: today);
      print('🔍 [Attendance] _loadTodayAttendance: received attendance: ${attendance?.attendanceId}, morningIn: ${attendance?.morningIn}');
      
      if (mounted) {
        setState(() {
          // Only set today's attendance if it exists and is from today
          if (attendance != null) {
            // Verify the attendance date matches today
            final attendanceDate = attendance.date;
            final isSameDay = attendanceDate.year == DateTime.now().year && 
                            attendanceDate.month == DateTime.now().month && 
                            attendanceDate.day == DateTime.now().day;
            
            print('🔍 [Attendance] Date comparison: attendanceDate=$attendanceDate, today=${DateTime.now()}, isSameDay=$isSameDay');
            
            if (isSameDay) {
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

  Future<void> _fetchAttendanceHistory() async {
    if (_studentId == null) return;
    try {
      final history = await AttendanceService.getAttendance(studentId: _studentId!);
      // Sort by date descending
      history.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _attendanceHistory = history;
        });
      }
    } catch (e) {
      print('Error fetching attendance history: $e');
    }
  }

  Future<void> _updateLocationSilently() async {
    if (kIsWeb) return;
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null && mounted) {
        final sites = await OjtSitesService.getSitesByCompanyName(_companyName);
        if (sites.isNotEmpty) {
          final nearestSite = sites.first; // Simpler for now
          final check = GeofenceService.check(
            nearestSite,
            position.latitude,
            position.longitude,
          );
          
          setState(() {
            _currentLat = position.latitude;
            _currentLng = position.longitude;
            _gpsAccuracy = position.accuracy;
            _siteName = nearestSite.name;
            _siteAddress = nearestSite.address;
            _distanceToSite = check.distanceMeters;
            _isInsideGeofence = check.inside;
          });
        }
      }
    } catch (e) {
      print('Silent location update failed: $e');
    }
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

  Future<void> _handleAttendance(String segment) async {
    final label = _segmentToLabel[segment] ?? segment;
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    final isTimeIn = AttendanceSegments.isTimeIn(segment);

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

    // PROACTIVELY CHECK LOCATION!
    bool locationFetched = false;
    Position? position;
    
    // Show a small non-blocking progress if location takes time
    try {
      final locEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (locEnabled && (permission == LocationPermission.whileInUse || permission == LocationPermission.always)) {
         try {
           position = await Geolocator.getCurrentPosition(
             timeLimit: const Duration(seconds: 20),
             desiredAccuracy: LocationAccuracy.high,
           );
         } catch (e) {
           debugPrint("Location timeout or error: $e");
           // One-time retry if timeout
           if (e is TimeoutException) {
             position = await Geolocator.getCurrentPosition(
               timeLimit: const Duration(seconds: 10),
               desiredAccuracy: LocationAccuracy.medium,
             );
           }
         }
      }
    } catch (e) {
      debugPrint("Pre-attendance location check failed: $e");
    }

    if (position != null) {
      locationFetched = true;
      // Fetch geofence site for this student's company
      final sites = await OjtSitesService.getSitesByCompanyName(_companyName);
      if (sites.isNotEmpty && GeofenceConfig.enforceGeofence) {
        GeofenceSite nearestSite = sites.first;
        ({bool inside, double distanceMeters}) bestGeofence = GeofenceService.check(
          nearestSite,
          position.latitude,
          position.longitude,
        );
        
        for (int i = 1; i < sites.length; i++) {
          final check = GeofenceService.check(
            sites[i],
            position.latitude,
            position.longitude,
          );
          if (check.distanceMeters < bestGeofence.distanceMeters) {
            nearestSite = sites[i];
            bestGeofence = check;
          }
        }
        
        final geofence = bestGeofence;
        
        insideGeofence = geofence.inside;
        distanceM = geofence.distanceMeters;

        // Show professional verification panel before camera opens
        if (mounted) {
          final proceed = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => GeofenceVerificationPanel(
                  siteName: nearestSite.name,
                  siteAddress: nearestSite.address,
                  siteLatitude: nearestSite.latitude,
                  siteLongitude: nearestSite.longitude,
                  currentLatitude: position!.latitude,
                  currentLongitude: position!.longitude,
                  distanceMeters: distanceM,
                  accuracyMeters:
                      position!.accuracy > 0 ? position!.accuracy : null,
                  insideGeofence: insideGeofence,
                  trustScore: trustScore,
                  onProceed: () => Navigator.pop(ctx, true),
                ),
              ) ??
              false;

          if (!proceed) return; // cancelled or blocked
        }

        if (!geofence.inside && GeofenceConfig.blockOutsideGeofence) {
          return;
        }
      }
      
      // Trust evaluation (mock, teleport, low accuracy)
      // Only run on mobile as web doesn't support mock detection well
      if (!kIsWeb) {
        final trust = await LocationSecurityService.evaluate(position);
        if (GeofenceConfig.blockIfMockLocation && (trust.evidence.isMock == true)) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Location not allowed'),
                content: const Text('Mock or simulated location is not allowed for attendance.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                ],
              ),
            );
          }
          return;
        }
        trustScore = trust.result.score;
        trustFlags = trust.result.reasons.isEmpty ? null : trust.result.reasons;
      }
      
      if (isTimeIn) {
        checkinLat = position.latitude;
        checkinLng = position.longitude;
      } else {
        checkoutLat = position.latitude;
        checkoutLng = position.longitude;
      }
      accuracyM = position.accuracy > 0 ? position.accuracy : null;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb 
              ? "ℹ️ Browser location unavailable. High accuracy might be disabled." 
              : "⚠️ GPS signal weak. Recorded without location."),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
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
        
        // Get current date and time in local format
        final now = DateTime.now();
        final today = DateFormat('yyyy-MM-dd').format(now);
        final currentTime = DateFormat('HH:mm:ss').format(now);
        
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
            timeIn: currentTime,
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
            timeOut: currentTime,
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
              content: Text("✅ $label recorded and approved at $timeNow\n📸 Image saved and verified"),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh only history and location; today's state is already updated locally
          _fetchAttendanceHistory();
          _updateLocationSilently();
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
          final errorMsg = e.toString();
          
          if (errorMsg.contains('IDENTITY_VERIFICATION_FAILED')) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.face_retouching_off, color: Colors.red, size: 28),
                    SizedBox(width: 10),
                    Text("Verification Failed"),
                  ],
                ),
                content: const Text(
                  "The AI could not verify your identity. Please make sure:\n\n"
                  "• Your face is clearly visible\n"
                  "• You are in a well-lit area\n"
                  "• You are not wearing a mask or glasses\n\n"
                  "You must match your registration profile photo to record attendance.",
                  style: TextStyle(fontSize: 15),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Try Again"),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⚠️ Failed to save attendance: $e"),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.red,
              ),
            );
          }
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

  // ---------------- UI Components ----------------

  Widget _buildHeaderCard() {
    final now = DateFormat('MMMM d, yyyy').format(DateTime.now());
    String status = "Ready to Time In";
    Color statusColor = AppTheme.warningColor;
    
    if (_todayAttendance != null) {
      if (_todayAttendance!.morningIn != null && _todayAttendance!.afternoonOut == null) {
        status = "On Duty";
        statusColor = AppTheme.successColor;
      } else if (_todayAttendance!.afternoonOut != null) {
        status = "Completed for Today";
        statusColor = AppTheme.infoColor;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Attendance Today", style: AppTheme.bodySmall),
                    Text(now, style: AppTheme.heading3),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            const Divider(),
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Schedule: 8:00 AM – 12:00 PM | 1:00 PM – 5:00 PM",
                    style: AppTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Have a productive day at your OJT site!",
              style: AppTheme.bodyMedium.copyWith(fontStyle: FontStyle.italic, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }

  // --- Modular Components Implementation ---
  
  Widget _buildGeofencePanel() {
    return GeofenceStatusPanel(
      isInsideGeofence: _isInsideGeofence,
      siteName: _siteName ?? _companyName,
      siteAddress: _siteAddress ?? _companyAddress,
      currentLat: _currentLat,
      currentLng: _currentLng,
      distanceToSite: _distanceToSite,
      gpsAccuracy: _gpsAccuracy,
    );
  }

  Widget _buildPhotoCard() {
    return AttendancePhotoEvidence(
      imageBytes: _attendanceImageBytes,
      onRetake: () => setState(() => _attendanceImageBytes = null),
    );
  }

  Widget _buildComputationCard() {
    return AttendanceSummaryCard(
      attendance: _todayAttendance,
      formatTime: _formatTimeForDisplay,
    );
  }

  Widget _buildActionButtons() {
    final now = DateTime.now();
    final isAfternoonTime = now.hour > 12 || (now.hour == 12 && now.minute >= 30);
    String? nextInSegment;
    String? nextOutSegment;

    if (_todayAttendance == null) {
      // If first punch of the day, suggest based on time
      nextInSegment = isAfternoonTime ? AttendanceSegments.afternoonIn : AttendanceSegments.morningIn;
    } else {
      final att = _todayAttendance!;
      
      // Check current state based on what's already logged, progressing linearly
      // If afternoon is active or completed, we completely ignore missing morning logs
      if (att.afternoonIn != null) {
        if (att.afternoonOut == null) {
          nextOutSegment = AttendanceSegments.afternoonOut;
        } else if (att.overtimeIn == null && (now.hour >= 17)) { // Only suggest OT if it's past 5 PM
          nextInSegment = AttendanceSegments.overtimeIn;
        } else if (att.overtimeIn != null && att.overtimeOut == null) {
          nextOutSegment = AttendanceSegments.overtimeOut;
        }
      } 
      // If nothing logged yet but it's afternoon, allow skipping morning
      else if (att.morningIn == null && isAfternoonTime) {
        nextInSegment = AttendanceSegments.afternoonIn;
      }
      // Normal morning flow
      else if (att.morningIn == null) {
        nextInSegment = AttendanceSegments.morningIn;
      } else if (att.morningOut == null) {
        nextOutSegment = AttendanceSegments.morningOut;
      } else {
        // Morning completed, prompt for afternoon
        nextInSegment = AttendanceSegments.afternoonIn;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          _buildMajorButton(
            label: nextInSegment != null ? "TIME IN (${AttendanceSegments.getLabel(nextInSegment)})" : "ALL IN RECORDED",
            onPressed: (_isLoading || _isInsideGeofence == false || nextInSegment == null) 
              ? null 
              : () => _handleAttendance(nextInSegment!),
            color: AppTheme.studentPrimary,
            icon: Icons.login,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildMajorButton(
            label: nextOutSegment != null ? "TIME OUT (${AttendanceSegments.getLabel(nextOutSegment)})" : "TIME OUT RECORDED",
            onPressed: (_isLoading || _isInsideGeofence == false || nextOutSegment == null)
              ? null
              : () => _handleAttendance(nextOutSegment!),
            color: Colors.orange,
            icon: Icons.logout,
          ),
          if (_isInsideGeofence == false)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Time In/Out disabled because you are outside geofence.",
                style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMajorButton({required String label, required VoidCallback? onPressed, required Color color, required IconData icon}) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_attendanceHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Center(child: Text("No attendance records yet.", style: AppTheme.bodySmall)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16, vertical: 8),
          child: Text("Recent History", style: AppTheme.heading3),
        ),
        ..._attendanceHistory.take(5).map((att) => _buildHistoryCard(att)),
      ],
    );
  }

  Widget _buildHistoryCard(Attendance att) {
    final dateStr = DateFormat('EEE, MMM d').format(att.date);
    final firstIn = att.morningIn ?? att.afternoonIn ?? att.overtimeIn ?? att.timeIn;
    final lastOut = att.overtimeOut ?? att.afternoonOut ?? att.morningOut ?? att.timeOut;
    
    return Card(
      child: ListTile(
        title: Text(dateStr, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Text("${_formatTimeForDisplay(firstIn)} - ${_formatTimeForDisplay(lastOut)}", style: AppTheme.bodySmall),
            const Spacer(),
            Text("${att.regularHours?.toStringAsFixed(1)} hrs", style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.successColor)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              att.insideGeofence == true ? Icons.verified : Icons.warning_amber_rounded,
              color: att.insideGeofence == true ? AppTheme.successColor : AppTheme.warningColor,
              size: 20,
            ),
            if (att.coordinatorComment != null)
              const Icon(Icons.comment, size: 14, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesCard() {
    return Card(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text("Attendance Rules", style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
              ],
            ),
            const SizedBox(height: 8),
            _buildRuleBullet("Regular hours: 8:00 AM–12:00 PM and 1:00 PM–5:00 PM."),
            _buildRuleBullet("Late arrivals are rounded in 30-minute blocks."),
            _buildRuleBullet("Early arrival does not add extra regular hours."),
            _buildRuleBullet("Staying beyond regular schedule requires OT approval."),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleBullet(String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(rule, style: AppTheme.bodySmall)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitializing && !_canPerformOjtActions) {
      return const RestrictedAccessScreen();
    }

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text("Daily Time Record")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Attendance"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadTodayAttendance();
              _fetchAttendanceHistory();
              _updateLocationSilently();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTodayAttendance();
          await _fetchAttendanceHistory();
          _updateLocationSilently();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildHeaderCard(),
            _buildGeofencePanel(),
            _buildPhotoCard(),
            _buildComputationCard(),
            const SizedBox(height: AppTheme.spacing16),
            _buildActionButtons(),
            const SizedBox(height: AppTheme.spacing24),
            _buildRulesCard(),
            _buildHistorySection(),
            const SizedBox(height: AppTheme.spacing32),
          ],
        ),
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

