import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class StudentChecklistScreen extends StatefulWidget {
  const StudentChecklistScreen({super.key});

  @override
  State<StudentChecklistScreen> createState() => _StudentChecklistScreenState();
}

class _StudentChecklistScreenState extends State<StudentChecklistScreen> {
  // --- File Upload Function ---
  Future<void> _uploadFile(String label) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final fileName = result.files.single.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ '$fileName' uploaded for '$label' successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ No file selected.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ File upload failed: $e")),
      );
    }
  }

  // --- Upload item widget ---
  Widget _buildUploadItem(String label) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Image.network(
        'https://cdn-icons-png.flaticon.com/512/1556/1556328.png',
        height: 28,
        width: 28,
      ),
      title: Text(label),
      trailing: IconButton(
        icon: Image.network(
          'https://cdn-icons-png.flaticon.com/512/724/724933.png',
          height: 30,
          width: 30,
        ),
        onPressed: () => _uploadFile(label),
      ),
    );
  }

  // --- OJT Checklist Section ---
  Widget _buildChecklistCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/2721/2721260.png',
                    height: 28,
                    width: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "OJT APPLICATION CHECKLIST",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/1828/1828640.png',
                    height: 24,
                    width: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "STEP 2 – SEEK YOUR OJT COORDINATOR",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildUploadItem("Application Letter (signed)"),
              _buildUploadItem("Comprehensive Resume (with photo & skills)"),
              _buildUploadItem("Recommendation Letter (from Coordinator)"),
              _buildUploadItem("Draft Memorandum of Agreement (MOA)"),

              const SizedBox(height: 16),
              Row(
                children: [
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/906/906175.png',
                    height: 24,
                    width: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "STEP 3 – APPLY TO THE HOST TRAINING ESTABLISHMENT",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildUploadItem("Application Letter - Submitted to HTE"),
              _buildUploadItem("Resume - Submitted to HTE"),
              _buildUploadItem("Recommendation Letter - Submitted to HTE"),
              _buildUploadItem("Draft MOA - Submitted to HTE"),
              _buildUploadItem("Accepted Recommendation Letter (from HTE)"),
              _buildUploadItem("Accepted or Revised MOA (from HTE)"),

              const SizedBox(height: 16),
              Row(
                children: [
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/2989/2989988.png',
                    height: 24,
                    width: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "STEP 4 – PREPARATION OF FINAL MOA",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildUploadItem("Final MOA (5 copies)"),
              _buildUploadItem("Proof of Notarization Payment"),

              const SizedBox(height: 16),
              Row(
                children: [
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/5974/5974900.png',
                    height: 24,
                    width: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "STEP 5 – SECURE REQUIRED DOCUMENTS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildUploadItem("Parent’s Consent and Waiver"),
              _buildUploadItem("Medical Certificate (Fit to Work)"),
              _buildUploadItem("Pregnancy Test (for female students)"),
              _buildUploadItem("OB-GYN Certificate (if applicable)"),
              _buildUploadItem("Chest X-ray"),
              _buildUploadItem("Hepatitis B Test"),
              _buildUploadItem("Blood Type Test"),
              _buildUploadItem("Urinalysis"),
              _buildUploadItem("Complete Blood Count (CBC)"),

              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/159/159606.png',
                    height: 22,
                    width: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "NOTE: Ensure your HTE indicates acceptance on the Recommendation Letter before proceeding to MOA signing.",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.network(
              'https://cdn-icons-png.flaticon.com/512/1584/1584894.png',
              height: 26,
              width: 26,
            ),
            const SizedBox(width: 8),
            const Text("OJT Application Checklist"),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildChecklistCard(),
      ),
    );
  }
}
