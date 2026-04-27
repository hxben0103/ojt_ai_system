import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../core/app_theme.dart';

class AttendancePhotoEvidence extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback onRetake;

  const AttendancePhotoEvidence({
    super.key,
    required this.imageBytes,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Photo Evidence", style: AppTheme.heading3),
                TextButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("Retake", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.memory(
                    imageBytes!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: const Text(
                        "Recorded time is based on this photo's capture timestamp.",
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
