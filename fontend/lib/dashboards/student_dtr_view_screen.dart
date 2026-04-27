import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../widgets/restricted_access_screen.dart';
import '../services/ojt_service.dart';
import '../services/auth_service.dart';
import '../../core/config.dart';

class StudentDTRViewScreen extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String course;
  final String? supervisorName; // Added supervisor name
  final Uint8List? certSigBytes; // optional signature image
  final List<Map<String, dynamic>> dtrRecords; // daily logs

  const StudentDTRViewScreen({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.course,
    required this.dtrRecords,
    this.supervisorName,
    this.certSigBytes,
  });

  @override
  State<StudentDTRViewScreen> createState() => _StudentDTRViewScreenState();
}

class _StudentDTRViewScreenState extends State<StudentDTRViewScreen> {
  bool _isLoading = true;
  bool _canPerformOjtActions = false;

  @override
  void initState() {
    super.initState();
    _checkOjtStatus();
  }

  Future<void> _checkOjtStatus() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user?.userId != null) {
        // ✅ COORDINATOR BYPASS: Coordinators can always view student DTRs
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_canPerformOjtActions) {
      return const RestrictedAccessScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student DTR Record"),
        backgroundColor: Colors.orange,
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: "DTR_${widget.studentName.replaceAll(' ', '_')}.pdf",
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // --- Header ---
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  InstitutionalConfig.universityName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  InstitutionalConfig.campusName,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  "DAILY TIME RECORD",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text("(Student OJT)", style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // --- Student Info Table ---
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(children: [
                _cell("Name:", alignRight: true),
                _cell(widget.studentName),
              ]),
              pw.TableRow(children: [
                _cell("ID Number:", alignRight: true),
                _cell(widget.studentId),
              ]),
              pw.TableRow(children: [
                _cell("Course:", alignRight: true),
                _cell(widget.course),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),

          // --- DTR Table ---
          _buildDTRTable(),

          pw.SizedBox(height: 25),

          // --- Signature Section ---
          _buildSignatureSection(),

          pw.SizedBox(height: 16),

          // --- Total Summary ---
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Hours: ${_calculateTotalHours().toStringAsFixed(2)} hrs",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // --- Build DTR Table ---
  pw.Widget _buildDTRTable() {
    final headers = [
      "Date",
      "Morning In",
      "Morning Out",
      "Afternoon In",
      "Afternoon Out",
      "Overtime In",
      "Overtime Out",
      "Ded. Mins",
      "Total Hours",
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((h) => _headerCell(h)).toList(),
        ),
        ...widget.dtrRecords.map((record) {
          return pw.TableRow(
            children: [
              _cell(record['date'] ?? "-"),
              _cell(record['amIn'] ?? "-"),
              _cell(record['amOut'] ?? "-"),
              _cell(record['pmIn'] ?? "-"),
              _cell(record['pmOut'] ?? "-"),
              _cell(record['otIn'] ?? "-"),
              _cell(record['otOut'] ?? "-"),
              _cell(record['deductionMinutes']?.toString() ?? "0", color: PdfColors.orange),
              _cell(record['totalHours']?.toString() ?? "0", color: PdfColors.teal),
            ],
          );
        }),
      ],
    );
  }

  // --- Signature Section ---
  pw.Widget _buildSignatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(children: [
          pw.Container(
            width: 220,
            height: 60,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: PdfColors.black),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Student Trainee', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(widget.studentName, style: const pw.TextStyle(fontSize: 10)),
        ]),
        pw.Column(children: [
          pw.Container(
            width: 220,
            height: 60,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: PdfColors.black),
              ),
            ),
            child: widget.certSigBytes != null
                ? pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(widget.certSigBytes!),
                      width: 100,
                      height: 50,
                    ),
                  )
                : null,
          ),
          pw.SizedBox(height: 4),
          pw.Text(widget.supervisorName ?? 'Industry Supervisor',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('Industry Supervisor / In-Charge',
              style: const pw.TextStyle(fontSize: 9)),
        ]),
      ],
    );
  }

  // --- Helper Functions ---
  pw.Widget _headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Center(
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );

  pw.Widget _cell(String? text, {bool alignRight = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Align(
          alignment:
              alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(
            text ?? "",
            style: pw.TextStyle(
              fontSize: 9,
              color: color,
            ),
          ),
        ),
      );

  double _calculateTotalHours() {
    double total = 0;
    for (var rec in widget.dtrRecords) {
      total += double.tryParse(rec['totalHours']?.toString() ?? '0') ?? 0;
    }
    return total;
  }
}

