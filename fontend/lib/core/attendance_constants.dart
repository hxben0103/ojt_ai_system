// Attendance segment constants
class AttendanceSegments {
  // Time In segments
  static const String morningIn = 'MORNING_IN';
  static const String afternoonIn = 'AFTERNOON_IN';
  static const String overtimeIn = 'OVERTIME_IN';
  
  // Time Out segments
  static const String morningOut = 'MORNING_OUT';
  static const String afternoonOut = 'AFTERNOON_OUT';
  static const String overtimeOut = 'OVERTIME_OUT';
  
  // Display labels
  static const Map<String, String> labels = {
    morningIn: 'Morning In',
    morningOut: 'Morning Out',
    afternoonIn: 'Afternoon In',
    afternoonOut: 'Afternoon Out',
    overtimeIn: 'Overtime In',
    overtimeOut: 'Overtime Out',
  };
  
  // Get label for a segment
  static String getLabel(String segment) {
    return labels[segment] ?? segment;
  }
  
  // Check if segment is a time-in
  static bool isTimeIn(String segment) {
    return segment.endsWith('_IN');
  }
  
  // Check if segment is a time-out
  static bool isTimeOut(String segment) {
    return segment.endsWith('_OUT');
  }
}

