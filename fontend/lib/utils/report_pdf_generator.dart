import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/system_report.dart';
import '../core/config.dart';

class ReportPdfGenerator {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy HH:mm');

  static Future<Uint8List> generateReportPdf(SystemReport report) async {
    final pdf = pw.Document();
    final title = report.content['title'] ?? report.reportType;
    final generatedAt = report.createdAt ?? DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(title, report.generatedByName ?? 'Coordinator'),
          pw.SizedBox(height: 10),
          pw.Text('Report Type: ${report.reportType}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text('Generated At: ${_dateFormat.format(generatedAt)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Divider(height: 30, thickness: 1, color: PdfColors.grey300),
          
          if ((report.reportType == 'Coordinator Summary' || report.reportType == 'Admin Master Summary') && report.content['students'] != null)
            _buildSummaryTable(report.content['students'] as List<dynamic>)
          else
            _buildIndividualReportContent(report),
            
          pw.Spacer(),
          
          // --- Signature Section ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 180,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black)),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (report.content['supervisor_name'] != null) ...[
                    pw.Text(report.content['supervisor_name'], style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Industry Supervisor', style: const pw.TextStyle(fontSize: 9)),
                  ] else if (report.reportType.contains('Master Summary')) ...[
                    pw.Text(InstitutionalConfig.universityPresident, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(InstitutionalConfig.presidentTitle, style: const pw.TextStyle(fontSize: 9)),
                  ] else ...[
                    pw.Text(report.generatedByName ?? 'OJT Coordinator', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('OJT Coordinator', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 0.5),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('OJT AI Monitoring System - Official Report', 
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
        ],
      ),
    );

    // ADDED: Master Compliance Matrix (Landscape) for Summary Reports
    if ((report.reportType == 'Coordinator Summary' || report.reportType == 'Admin Master Summary') && report.content['students'] != null) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildComplianceMatrix(report.content['students'] as List<dynamic>),
        ),
      );
    }

    return pdf.save();
  }

  // Predefined requirement list for column consistency
  static const List<String> _matrixRequirements = [
    'Application Letter (signed)',
    'Comprehensive Resume (with photo & skills)',
    'Recommendation Letter (from Coordinator)',
    'Draft Memorandum of Agreement (MOA)',
    'Application Letter - Submitted to HTE',
    'Resume - Submitted to HTE',
    'Recommendation Letter - Submitted to HTE',
    'Draft MOA - Submitted to HTE',
    'Accepted Recommendation Letter (from HTE)',
    'Accepted or Revised MOA (from HTE)',
    'Final MOA (5 copies)',
    'Proof of Notarization Payment',
    'Parent\'s Consent and Waiver',
    'Medical Certificate (Fit to Work)',
    'Pregnancy Test (for female students)',
    'OB-GYN Certificate (if applicable)',
    'Chest X-ray',
    'Hepatitis B Test',
    'Blood Type Test',
    'Urinalysis',
    'Complete Blood Count (CBC)'
  ];

  static pw.Widget _buildComplianceMatrix(List<dynamic> students) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Master Requirement Compliance Matrix', 
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
        pw.SizedBox(height: 10),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(80), // Student Name
            for (int i = 1; i <= _matrixRequirements.length; i++) 
              i: const pw.IntrinsicColumnWidth(),
          },
          children: [
            // Header Row (Abbreviated)
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text('Student Name', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ),
                ...List.generate(_matrixRequirements.length, (index) => 
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text('R${index + 1}', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  )
                ),
              ],
            ),
            // Data Rows
            ...students.map((student) {
                final matrix = student['requirements_matrix'] as Map<String, dynamic>? ?? {};
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(student['student_name'] ?? 'Unknown', style: const pw.TextStyle(fontSize: 7)),
                    ),
                    ..._matrixRequirements.map((req) {
                      final status = matrix[req];
                      final isDone = status == 'Completed';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(isDone ? 'X' : '', 
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                            textAlign: pw.TextAlign.center),
                      );
                    }),
                  ],
                );
            }),
          ],
        ),
        
        pw.SizedBox(height: 15),
        pw.Text('Requirement Legend:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Wrap(
          spacing: 15,
          runSpacing: 5,
          children: List.generate(_matrixRequirements.length, (index) => 
            pw.SizedBox(
              width: 140,
              child: pw.Text('R${index + 1}: ${_matrixRequirements[index]}', style: const pw.TextStyle(fontSize: 6)),
            )
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHeader(String title, String generatedBy) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 2),
            pw.Text(InstitutionalConfig.universityName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(InstitutionalConfig.campusName, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Text('Coordinator: $generatedBy', style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        // Placeholder for Logo
        pw.Container(
          width: 60,
          height: 60,
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Text('OJT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryTable(List<dynamic> students) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Student List & Performance Summary', 
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
        pw.SizedBox(height: 15),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(1.8),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.1),
            4: const pw.FlexColumnWidth(0.8),
            5: const pw.FlexColumnWidth(1.1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
              children: [
                _headerCell('School ID'),
                _headerCell('Student Name'),
                _headerCell('Company'),
                _headerCell('Performance'),
                _headerCell('Progress'),
                _headerCell('Status'),
              ],
            ),
            ...students.map((s) {
              final progress = s['progress'] != null ? double.tryParse(s['progress'].toString())?.toStringAsFixed(0) ?? '0' : '0';
              final status = s['compliance_status']?.toString() ?? 'Pending';
              
              return pw.TableRow(
                children: [
                  _cell(s['school_id']?.toString() ?? 'N/A'),
                  _cell(s['student_name']?.toString() ?? 'Unknown'),
                  _cell(s['company']?.toString() ?? 'N/A'),
                  _cell(s['performance']?.toString() ?? 'N/A'),
                  _cell('$progress%'),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      status,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: status == 'Complied' ? PdfColors.green800 : PdfColors.grey700,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildIndividualReportContent(SystemReport report) {
    final Map<String, dynamic> content = report.content;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (content['student_name'] != null) ...[
          pw.Text('Student Information', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Name: ${content['student_name']}'),
          if (content['student_id'] != null) pw.Text('Student ID: ${content['student_id']}'),
          if (content['company'] != null) pw.Text('Company: ${content['company']}'),
          pw.SizedBox(height: 20),
        ],
        
        pw.Text('Detailed Content', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        
        if (content['requirements'] != null) ...[
          pw.SizedBox(height: 10),
          pw.Text('OJT Requirement Compliance', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(0.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Requirement Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Done', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                ],
              ),
              ...(content['requirements'] as List<dynamic>).map((req) {
                final isCompleted = req['status'] == 'Completed';
                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(req['requirement_name'] ?? 'Unknown', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6), 
                      child: pw.Center(
                        child: pw.Text(
                          isCompleted ? 'X' : '', // Using 'X' as a checkmark for standard font compatibility
                          style: pw.TextStyle(
                            fontSize: 12, 
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900
                          )
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            _formatContent(content),
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5),
          ),
        ),
      ],
    );
  }

  static String _formatContent(Map<String, dynamic> content) {
    // Exclude title and generic metadata
    final Map<String, dynamic> filtered = Map.from(content)
      ..remove('title')
      ..remove('generated_at')
      ..remove('period')
      ..remove('student_id')
      ..remove('student_name')
      ..remove('company')
      ..remove('requirements') // Don't show raw requirement data in format
      ..remove('student_id')
      ..remove('student_name')
      ..remove('company');
      
    if (filtered.isEmpty) return 'No detailed data available.';

    final buffer = StringBuffer();
    filtered.forEach((key, value) {
      final label = key.replaceAll('_', ' ').toUpperCase();
      buffer.writeln('$label:');
      if (value is Map || value is List) {
        buffer.writeln('  ${value.toString()}');
      } else {
        buffer.writeln('  $value');
      }
      buffer.writeln();
    });
    
    return buffer.toString();
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }
}

