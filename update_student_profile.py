import re

filepath = r"C:\Users\ACER\Desktop\OJT _AI_SYSTEM\fontend\lib\dashboards\student_dashboard.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old_profile_header_pattern = re.compile(r'  // ── Profile Header ──\n  Widget _buildProfileHeader\(\) \{.*?(?=  // ── 1\. Hero Performance Card ──)', re.DOTALL)

new_profile_header = """  // ── Profile Header ──
  Widget _buildProfileHeader() {
    ImageProvider? profileImageProvider;
    if (!kIsWeb && _profileImage != null) {
      try {
        profileImageProvider = file_helper.createImageProvider(_profileImage);
      } catch (_) {
        if (_profileImageBytes != null) {
          profileImageProvider = MemoryImage(_profileImageBytes!);
        }
      }
    } else if (_profileImageBytes != null) {
      profileImageProvider = MemoryImage(_profileImageBytes!);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.studentPrimary,
            AppTheme.studentPrimary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.studentPrimary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundImage: profileImageProvider,
              backgroundColor: Colors.white,
              child: profileImageProvider == null
                  ? Icon(Icons.person_rounded, size: 36, color: AppTheme.studentPrimary)
                  : null,
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _studentName ?? "Loading Profile...",
                  style: AppTheme.heading2.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "ID: ${_studentId ?? 'N/A'}",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white.withOpacity(0.9)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${_course ?? 'No Course Assigned'}",
                  style: AppTheme.bodySmall.copyWith(color: Colors.white.withOpacity(0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

"""

if old_profile_header_pattern.search(content):
    content = old_profile_header_pattern.sub(new_profile_header, content)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully updated student_dashboard.dart profile header.")
else:
    print("Could not find _buildProfileHeader pattern in student_dashboard.dart")
