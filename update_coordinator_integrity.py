import re

filepath = r"C:\Users\ACER\Desktop\OJT _AI_SYSTEM\fontend\lib\widgets\integrity_timeline_card.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace columns
old_columns = """                Expanded(flex: 3, child: _headerText("Date")),
                Expanded(flex: 3, child: _headerText("Geofence")),
                Expanded(flex: 3, child: _headerText("Trust")),
                Expanded(flex: 2, child: _headerText("Photo")),"""
new_columns = """                if (showStudent) Expanded(flex: 3, child: _headerText("Student")),
                Expanded(flex: 2, child: _headerText("Date")),
                Expanded(flex: 2, child: _headerText("Geofence")),
                Expanded(flex: 2, child: _headerText("Trust")),
                Expanded(flex: 2, child: _headerText("Photo")),
                Expanded(flex: 2, child: _headerText("Dist.")),"""
content = content.replace(old_columns, new_columns)

# Replace constructor to include showStudent
old_constructor = """  const IntegrityTimelineCard({
    Key? key,
    required this.attendanceHistory,
  }) : super(key: key);"""
new_constructor = """  final bool showStudent;

  const IntegrityTimelineCard({
    Key? key,
    required this.attendanceHistory,
    this.showStudent = false,
  }) : super(key: key);"""
content = content.replace(old_constructor, new_constructor)

# Replacing _buildRow
old_row = """        children: [
          // Date
          Expanded(
            flex: 3,
            child: Text(
              formatter.format(attendance.date),
              style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Geofence badge
          Expanded(
            flex: 3,
            child: _buildBadge(geofenceText, geofenceColor),
          ),
          // Trust badge
          Expanded(
            flex: 3,
            child: _buildBadge(trustLabel, trustColor),
          ),
          // Photo link
          Expanded(
            flex: 2,"""

new_row = """        children: [
          if (showStudent)
            Expanded(
              flex: 3,
              child: Text(
                attendance.studentName ?? 'Unknown',
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              formatter.format(attendance.date),
              style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade800, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Geofence badge
          Expanded(
            flex: 2,
            child: _buildBadge(geofenceText, geofenceColor),
          ),
          // Trust badge
          Expanded(
            flex: 2,
            child: _buildBadge(trustLabel, trustColor),
          ),
          // Photo link
          Expanded(
            flex: 2,"""

content = content.replace(old_row, new_row)

old_end_row = """                  )
                : Text(
                    "—",
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.grey.shade400,
                      fontSize: 10,
                    ),
                  ),
          ),
          // Map icon (tappable when location exists)
          SizedBox("""

new_end_row = """                  )
                : Text(
                    "—",
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.grey.shade400,
                      fontSize: 10,
                    ),
                  ),
          ),
          // Distance
          Expanded(
            flex: 2,
            child: Text(
              "N/A", // Distance native
              style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade600, fontSize: 10),
            ),
          ),
          // Map icon (tappable when location exists)
          SizedBox("""
content = content.replace(old_end_row, new_end_row)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated integrity_timeline_card.dart successfully')


filepath_coord = r"C:\Users\ACER\Desktop\OJT _AI_SYSTEM\fontend\lib\dashboards\coordinator_dashboard.dart"
with open(filepath_coord, 'r', encoding='utf-8') as f:
    content_coord = f.read()

old_timeline = """        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: IntegrityTimelineCard(
            attendanceHistory: recentEntries,
          ),
        );"""
new_timeline = """        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: IntegrityTimelineCard(
            attendanceHistory: recentEntries,
            showStudent: true,
          ),
        );"""
content_coord = content_coord.replace(old_timeline, new_timeline)

with open(filepath_coord, 'w', encoding='utf-8') as f:
    f.write(content_coord)

print('Updated coordinator_dashboard.dart successfully')
