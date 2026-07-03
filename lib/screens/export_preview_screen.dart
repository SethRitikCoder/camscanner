import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../services/ad_service.dart';
import '../services/compression_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';

class ExportPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String docTitle;
  final String? folderName;

  const ExportPreviewScreen({
    super.key,
    required this.imagePaths,
    required this.docTitle,
    this.folderName,
  });

  @override
  State<ExportPreviewScreen> createState() => _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends State<ExportPreviewScreen> {
  CompressionQuality _selectedQuality = CompressionQuality.medium;
  String _estimatedSizeText = "Calculating...";
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _calculateSize();
    AdService.loadInterstitialAd();
  }

  Future<void> _calculateSize() async {
    setState(() => _estimatedSizeText = "Calculating...");
    final bytes = await CompressionService.estimateCompressedSize(widget.imagePaths, _selectedQuality);
    if (mounted) {
      setState(() => _estimatedSizeText = CompressionService.formatBytes(bytes));
    }
  }

  Future<void> _exportDocument({required bool isPdf}) async {
    setState(() => _isExporting = true);

    try {
      final List<File> compressedFiles = [];
      for (String path in widget.imagePaths) {
        final sourceFile = File(path);
        if (sourceFile.existsSync() || await sourceFile.exists()) {
          final cmpFile = await CompressionService.compressImage(sourceFile, _selectedQuality);
          compressedFiles.add(cmpFile);
        }
      }

      if (compressedFiles.isEmpty) {
        // Fallback to trying all paths as files directly
        for (String path in widget.imagePaths) {
          compressedFiles.add(File(path));
        }
      }

      final cleanTitle = widget.docTitle.replaceAll(RegExp(r'[^\w\.-]'), '_');

      if (isPdf) {
        final pdfFile = await PdfService.generatePdf(
          compressedFiles,
          cleanTitle,
          folderName: widget.folderName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported PDF: ${pdfFile.path}')),
          );
          try {
            await Share.shareXFiles(
              [XFile(pdfFile.path, mimeType: 'application/pdf')],
              text: widget.docTitle,
            );
          } catch (_) {
            // Platform share dialog fallback
          }
        }
      } else {
        // Copy images to the dedicated public folder
        final outputDir = await StorageService.getPublicDirectory(folderName: widget.folderName);
        final List<File> savedImageFiles = [];
        final safeTitle = widget.docTitle.replaceAll(':', '-').replaceAll(RegExp(r'[\\*?"<>|]'), '_');
        for (int i = 0; i < compressedFiles.length; i++) {
          final file = compressedFiles[i];
          final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
          
          var targetFile = File(p.join(outputDir.path, '${safeTitle}_page_${i + 1}$ext'));
          int counter = 1;
          while (await targetFile.exists()) {
            targetFile = File(p.join(outputDir.path, '${safeTitle}_page_${i + 1}_$counter$ext'));
            counter++;
          }
          
          await file.copy(targetFile.path);
          savedImageFiles.add(targetFile);
        }

        final xFiles = savedImageFiles.map((f) => XFile(f.path, mimeType: 'image/jpeg')).toList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${xFiles.length} Image(s) to ${outputDir.path}')),
          );
          try {
            await Share.shareXFiles(xFiles, text: widget.docTitle);
          } catch (_) {
            // Platform share dialog fallback
          }
        }
      }

      AdService.showInterstitialAd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _openImageZoom(File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.90),
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
            Expanded(
              child: PageView.builder(
                itemCount: widget.imagePaths.length,
                itemBuilder: (context, index) {
                  final file = File(widget.imagePaths[index]);
                  return GestureDetector(
                    onTap: () => _openImageZoom(file),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: Image.file(file, fit: BoxFit.contain),
                            ),
                            const Positioned(
                              bottom: 12,
                              right: 12,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.zoom_in, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Size Optimization",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<CompressionQuality>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: CompressionQuality.low, label: Text("Low")),
                          ButtonSegment(value: CompressionQuality.medium, label: Text("Medium")),
                          ButtonSegment(value: CompressionQuality.original, label: Text("Original")),
                        ],
                        selected: {_selectedQuality},
                        onSelectionChanged: (Set<CompressionQuality> newSelection) {
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
                        const Text("Estimated Size:", style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          _estimatedSizeText,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A86B), fontSize: 16),
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
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: _isExporting
            ? const SizedBox(
                height: 48,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00A86B)),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _exportDocument(isPdf: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00A86B),
                        side: const BorderSide(color: Color(0xFF00A86B)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Export JPEG", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _exportDocument(isPdf: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A86B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("Export PDF", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
