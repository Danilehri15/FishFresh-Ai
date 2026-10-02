import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/app_provider.dart';
import '../../core/theme.dart';
import 'result_view.dart';

class ScannerView extends StatefulWidget {
  final int initialTab;
  const ScannerView({super.key, this.initialTab = 0});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String _selectedFileName = '';
  final int _selectedOrganIndex = 0; // 0: Whole Fish, 1: Eye Crop, 2: Gill Crop

  final List<String> _organGuides = [
    "Whole Body: Position the entire fish horizontally inside the frame.",
    "Eye Inspection: Focus closely on the pupil clarity and cornea.",
    "Gill Inspection: Gently open gill operculum to scan red/brown color."
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedFileName = file.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _runScan() async {
    if (_selectedImageBytes == null) return;
    final state = context.read<AppStateProvider>();

    try {
      final res = await state.scanFishImage(_selectedImageBytes!, _selectedFileName);
      if (mounted && res != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultView(result: res, imageBytes: _selectedImageBytes)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.spoiledRed,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Fish Scanner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Organ Segmented Switcher removed as requested

            const SizedBox(height: 12),

            // 2. Guide Text
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _organGuides[_selectedOrganIndex],
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Viewfinder / Image Preview Box
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _selectedImageBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                              onPressed: () => setState(() => _selectedImageBytes = null),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 54, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'Capture or upload a fish photo',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports JPG, PNG, WEBP',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Capture Controls
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.primaryTeal),
                    ),
                    icon: const Icon(Icons.camera_alt, color: AppTheme.primaryTeal),
                    label: const Text('Camera', style: TextStyle(color: AppTheme.primaryTeal)),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.accentCyan),
                    ),
                    icon: const Icon(Icons.photo_library, color: AppTheme.accentCyan),
                    label: const Text('Gallery', style: TextStyle(color: AppTheme.accentCyan)),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 5. Submit Scan Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: state.isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  state.isScanning ? 'Analyzing with MobileNetV3 AI...' : 'Run Quality Scan',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: (_selectedImageBytes != null && !state.isScanning) ? _runScan : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
