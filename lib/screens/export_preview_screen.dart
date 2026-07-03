import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../services/ad_service.dart';
import '../services/compression_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/watermark_service.dart';

class ExportPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String docTitle;
  final String? folderName;
  final Color initialColor;
  final double initialOpacity;

  const ExportPreviewScreen({
    super.key,
    required this.imagePaths,
    required this.docTitle,
    this.folderName,
    this.initialColor = Colors.grey,
    this.initialOpacity = 0.30,
  });

  @override
  State<ExportPreviewScreen> createState() => _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends State<ExportPreviewScreen> {
  CompressionQuality _selectedQuality = CompressionQuality.medium;
  String _estimatedSizeText = "Calculating...";
  bool _isExporting = false;

  // Color/Opacity change track karne ke liye loaders aur list
  bool _isLiveUpdating = false;
  List<File> _previewFiles = [];

  late Color _selectedWatermarkColor;
  late double _selectedOpacity;

  @override
  void initState() {
    super.initState();
    _selectedWatermarkColor = widget.initialColor;
    _selectedOpacity = widget.initialOpacity;
    _calculateSize();
    _generateLivePreviews(); // Pehli baar screen khulne par image generate hogi
    AdService.loadInterstitialAd();
  }

  // CORE FIX: Jab bhi aap color ya slider badlenge, ye function photo ko naye attributes ke sath re-render karega
  Future<void> _generateLivePreviews() async {
    if (!mounted) return;
    setState(() => _isLiveUpdating = true);

    try {
      List<File> temporaryPreviews = [];
      for (String path in widget.imagePaths) {
        final originalFile = File(path);
        if (originalFile.existsSync()) {
          final updatedFile = await WatermarkService.applyWatermark(
            sourceFile: originalFile,
            text: "DocScanner Pro",
            opacity: _selectedOpacity,
            watermarkColor: _selectedWatermarkColor,
          );
          temporaryPreviews.add(updatedFile);
        }
      }
      if (mounted) {
        setState(() {
          _previewFiles = temporaryPreviews;
          _isLiveUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLiveUpdating = false);
    }
  }

  Future<void> _calculateSize() async {
    setState(() => _estimatedSizeText = "Calculating...");
    final bytes = await CompressionService.estimateCompressedSize(
        widget.imagePaths, _selectedQuality);
    if (mounted) {
      setState(
          () => _estimatedSizeText = CompressionService.formatBytes(bytes));
    }
  }

  void _openImageZoom(File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file),
            ),
            Positioned(
              top: 16 + MediaQuery.of(context).padding.top,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Color selection chip widget
  Widget _buildColorChip(Color color, String label) {
    final isSelected = _selectedWatermarkColor == color;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isLiveUpdating) return;
          setState(() {
            _selectedWatermarkColor = color;
          });
          _generateLivePreviews(); // Color badalte hi live update
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.grey.shade50,
            border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(backgroundColor: color, radius: 5),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Export Preview"),
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image Preview Container
            Expanded(
              child: Stack(
                children: [
                  _previewFiles.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00A86B)))
                      : PageView.builder(
                          itemCount: _previewFiles.length,
                          itemBuilder: (context, index) {
                            final currentFile = _previewFiles[index];

                            return GestureDetector(
                              onTap: () => _openImageZoom(
                                  currentFile), // Tap karne par zoom khulega
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12, blurRadius: 8)
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: Image.file(currentFile,
                                            fit: BoxFit.contain),
                                      ),
                                      // Niche right corner par chhota sa Zoom Icon indicator
                                   const   Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.black54,
                                          child: Icon(Icons.zoom_in,
                                              color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  // Jab user change karega tab halka loading overlay
                  if (_isLiveUpdating && _previewFiles.isNotEmpty)
                    Container(
                      color: Colors.black12,
                      child: const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF00A86B)),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Style Card
            Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Watermark Style",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildColorChip(Colors.grey, "Grey"),
                        const SizedBox(width: 8),
                        _buildColorChip(Colors.blue, "Blue"),
                        const SizedBox(width: 8),
                        _buildColorChip(Colors.red, "Red"),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // RANGE SLIDER ADDED: Dots waala proper Slider jo aapko chahiye tha!
                    Row(
                      children: [
                        const Text(
                          "Opacity:",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF00A86B),
                              inactiveTrackColor: Colors.grey.shade200,
                              thumbColor: const Color(0xFF00A86B),
                              overlayColor: const Color(0xFF00A86B)
                                  .withValues(alpha: 0.2),
                              tickMarkShape: const RoundSliderTickMarkShape(
                                  tickMarkRadius: 2.5),
                              activeTickMarkColor: const Color(0xFF00A86B),
                              inactiveTickMarkColor: Colors.grey.shade400,
                            ),
                            child: Slider(
                              value: _selectedOpacity,
                              min: 0.10,
                              max: 0.80,
                              divisions:
                                  7, // Discrete ranges (jaise 0.1, 0.2, 0.3 dots ki tarah)
                              label: _selectedOpacity.toStringAsFixed(2),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedOpacity = newValue;
                                });
                              },
                              onChangeEnd: (newValue) {
                                _generateLivePreviews(); // Slider chhodte hi image live update ho jayegi!
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1, thickness: 0.5),
                    ),
                    const Text(
                      "Size Optimization",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<CompressionQuality>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                              value: CompressionQuality.low,
                              label: Text("Low")),
                          ButtonSegment(
                              value: CompressionQuality.medium,
                              label: Text("Medium")),
                          ButtonSegment(
                              value: CompressionQuality.original,
                              label: Text("Original")),
                        ],
                        selected: {_selectedQuality},
                        onSelectionChanged:
                            (Set<CompressionQuality> newSelection) {
                          setState(() {
                            _selectedQuality = newSelection.first;
                          });
                          _calculateSize();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Estimated Size:",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          _estimatedSizeText,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00A86B),
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text("Export JPEG"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text("Export PDF"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
