import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StudentDTRViewScreen extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String course;
  final Uint8List? certSigBytes; // optional signature image
  final List<Map<String, dynamic>> dtrRecords; // daily logs

  const StudentDTRViewScreen({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.course,
    required this.dtrRecords,
    this.certSigBytes,
  });

  @override
  Widget build(BuildContext context) {
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
        pdfFileName: "DTR_${studentName.replaceAll(' ', '_')}.pdf",
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
                _cell(studentName),
              ]),
              pw.TableRow(children: [
                _cell("ID Number:", alignRight: true),
                _cell(studentId),
              ]),
              pw.TableRow(children: [
                _cell("Course:", alignRight: true),
                _cell(course),
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
      "Total Hours",
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((h) => _headerCell(h)).toList(),
        ),
        ...dtrRecords.map((record) {
          return pw.TableRow(
            children: [
              _cell(record['date'] ?? "-"),
              _cell(record['amIn'] ?? "-"),
              _cell(record['amOut'] ?? "-"),
              _cell(record['pmIn'] ?? "-"),
              _cell(record['pmOut'] ?? "-"),
              _cell(record['otIn'] ?? "-"),
              _cell(record['otOut'] ?? "-"),
              _cell(record['totalHours']?.toString() ?? "0"),
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
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: PdfColors.black),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Student Trainee', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(studentName, style: const pw.TextStyle(fontSize: 10)),
        ]),
        pw.Column(children: [
          pw.Container(
            width: 220,
            height: 60,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: PdfColors.black),
              ),
            ),
            child: certSigBytes != null
                ? pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(certSigBytes!),
                      width: 100,
                      height: 50,
                    ),
                  )
                : null,
          ),
          pw.SizedBox(height: 4),
          pw.Text('Certified By (In-Charge)',
              style: const pw.TextStyle(fontSize: 10)),
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

  pw.Widget _cell(String? text, {bool alignRight = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Align(
          alignment:
              alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(
            text ?? "",
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      );

  double _calculateTotalHours() {
    double total = 0;
    for (var rec in dtrRecords) {
      total += double.tryParse(rec['totalHours']?.toString() ?? '0') ?? 0;
    }
    return total;
  }
}
