import 'package:flutter/material.dart';
import '../../models/narrative_report.dart';
import '../../services/ojt_service.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'coordinator_student_reports_screen.dart';

class CoordinatorNarrativeReviewScreen extends StatefulWidget {
  const CoordinatorNarrativeReviewScreen({super.key});

  @override
  State<CoordinatorNarrativeReviewScreen> createState() => _CoordinatorNarrativeReviewScreenState();
}

class _CoordinatorNarrativeReviewScreenState extends State<CoordinatorNarrativeReviewScreen> {
  bool _isLoading = true;
  List<NarrativeReport> _allReports = [];
  List<Map<String, dynamic>> _studentsWithReports = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await OjtService.getNarrativeReports();
      
      // Group by student
      final Map<int, Map<String, dynamic>> studentMap = {};
      for (var report in reports) {
        if (report.studentId == null) continue;
        
        if (!studentMap.containsKey(report.studentId)) {
          studentMap[report.studentId!] = {
            'id': report.studentId,
            'name': report.studentName ?? 'Unknown Student',
            'reportCount': 0,
            'pendingCount': 0,
            'avgRating': 0.0,
            'reports': <NarrativeReport>[],
          };
        }
        
        final stud = studentMap[report.studentId]!;
        stud['reportCount']++;
        if (report.status == 'Pending') stud['pendingCount']++;
        (stud['reports'] as List<NarrativeReport>).add(report);
      }

      final studentList = studentMap.values.toList();
      studentList.sort((a, b) => (b['pendingCount'] as int).compareTo(a['pendingCount'] as int));

      setState(() {
        _allReports = reports;
        _studentsWithReports = studentList;
        _filteredStudents = studentList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _studentsWithReports;
      } else {
        _filteredStudents = _studentsWithReports
            .where((s) => s['name'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'Narrative Reviews',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.coordinatorPrimary))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    _buildSearchBar(),
                    Expanded(
                      child: _filteredStudents.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                return _buildStudentCard(student);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: _filterStudents,
        decoration: InputDecoration(
          hintText: 'Search by student name...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty 
                ? 'No reports submitted yet.' 
                : 'No students match your search.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final int pending = student['pendingCount'];
    final int total = student['reportCount'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CoordinatorStudentReportsScreen(
                  studentId: student['id'],
                  studentName: student['name'],
                  reports: student['reports'],
                ),
              ),
            );
            if (result == true) _fetchData();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.coordinatorPrimary.withOpacity(0.1),
                  child: Text(
                    student['name'][0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.coordinatorPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'],
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total total reports submitted',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (pending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pending PENDING',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
