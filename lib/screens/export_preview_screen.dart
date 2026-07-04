import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; //hii
import 'package:path/path.dart' as p;
import '../services/ad_service.dart';
import '../services/compression_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/watermark_service.dart';
import '../services/document_enhancer_service.dart'; // Enhancer service ko link kiya

class ExportPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String docTitle;
  final String? folderName;
  final Color initialColor;
  final double initialOpacity;
  final bool isEnhancerFlow;
  final bool isPdfConvertorFlow;
  final bool showWatermarkControls;
  final String watermarkText;

  const ExportPreviewScreen({
    super.key,
    required this.imagePaths,
    required this.docTitle,
    this.folderName,
    this.initialColor = Colors.grey,
    this.initialOpacity = 0.30,
    this.isEnhancerFlow = false,
    this.isPdfConvertorFlow = false,
    this.showWatermarkControls = false,
    this.watermarkText = "DocScanner Pro",
  });

  @override
  State<ExportPreviewScreen> createState() => _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends State<ExportPreviewScreen> {
  CompressionQuality _selectedQuality = CompressionQuality.medium;
  String _estimatedSizeText = "Calculating...";
  bool _isExportingJpeg = false;
  bool _isExportingPdf = false;

  bool _isLiveUpdating = false;
  List<File> _previewFiles = [];

  late Color _selectedWatermarkColor;
  late double _selectedOpacity;

  // CamScanner Filter Engine Variables
  String _selectedFilterMode = "Magic Color";

  @override
  void initState() {
    super.initState();
    _selectedWatermarkColor = widget.initialColor;
    _selectedOpacity = widget.initialOpacity;
    _calculateSize();
    _generateLivePreviews();
    AdService.loadInterstitialAd();
  }

  // Live Engine: Dono flows (Watermark aur Enhancer Filters) ko single pipeline me set kiya
  Future<void> _generateLivePreviews() async {
    if (!mounted) return;
    setState(() => _isLiveUpdating = true);

    try {
      List<File> temporaryPreviews = [];
      for (String path in widget.imagePaths) {
        final originalFile = File(path);
        if (originalFile.existsSync()) {
          File processedFile = originalFile;

          if (widget.isEnhancerFlow) {
            if (_selectedFilterMode == "Magic Color") {
              processedFile =
                  await DocumentEnhancerService.enhanceImage(originalFile);
            } else if (_selectedFilterMode == "Original") {
              processedFile = originalFile;
            } else {
              processedFile =
                  await DocumentEnhancerService.enhanceImage(originalFile);
            }
          } else if (widget.showWatermarkControls) {
            processedFile = await WatermarkService.applyWatermark(
              sourceFile: originalFile,
              text: widget.watermarkText,
              opacity: _selectedOpacity,
              watermarkColor: _selectedWatermarkColor,
            );
          }
          temporaryPreviews.add(processedFile);
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

  Widget _buildColorChip(Color color, String label) {
    final isSelected = _selectedWatermarkColor == color;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isLiveUpdating) return;
          setState(() {
            _selectedWatermarkColor = color;
          });
          _generateLivePreviews();
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

  // Premium Custom Filter Item Component for CamScanner Look
  Widget _buildFilterItem(String modeName, IconData iconData) {
    final isSelected = _selectedFilterMode == modeName;
    return GestureDetector(
      onTap: () {
        if (_isLiveUpdating || isSelected) return;
        setState(() {
          _selectedFilterMode = modeName;
        });
        _generateLivePreviews();
      },
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F6F0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A86B) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              color:
                  isSelected ? const Color(0xFF00A86B) : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              modeName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color:
                    isSelected ? const Color(0xFF00A86B) : Colors.grey.shade700,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title:
            Text(widget.isEnhancerFlow ? "Enhance & Export" : "Export Preview"),
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Preview Area
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
                              onTap: () => _openImageZoom(currentFile),
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 12,
                                        offset: Offset(0, 4))
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.white,
                                          child: Image.file(currentFile,
                                              fit: BoxFit.contain),
                                        ),
                                      ),
                                      const Positioned(
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

            // Premium Bottom Layout Changer Control
            widget.isEnhancerFlow
                ? Container(
                    height: 100,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildFilterItem("Original", Icons.image_outlined),
                        _buildFilterItem("Magic Color", Icons.auto_fix_high),
                        _buildFilterItem("Sharp B&W", Icons.palette_outlined),
                        _buildFilterItem(
                            "Clean Gray", Icons.filter_b_and_w_outlined),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      if (widget.showWatermarkControls)
                        Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
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
                                const SizedBox(height: 12),
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
                                          activeTrackColor:
                                              const Color(0xFF00A86B),
                                          inactiveTrackColor:
                                              Colors.grey.shade200,
                                          thumbColor: const Color(0xFF00A86B),
                                          overlayColor: const Color(0xFF00A86B)
                                              .withValues(alpha: 0.2),
                                          tickMarkShape:
                                              const RoundSliderTickMarkShape(
                                                  tickMarkRadius: 2.5),
                                          activeTickMarkColor:
                                              const Color(0xFF00A86B),
                                          inactiveTickMarkColor:
                                              Colors.grey.shade400,
                                        ),
                                        child: Slider(
                                          value: _selectedOpacity,
                                          min: 0.10,
                                          max: 0.80,
                                          divisions: 7,
                                          label: _selectedOpacity
                                              .toStringAsFixed(2),
                                          onChanged: (newValue) {
                                            setState(() {
                                              _selectedOpacity = newValue;
                                            });
                                          },
                                          onChangeEnd: (newValue) {
                                            _generateLivePreviews();
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      Card(
                        margin: EdgeInsets.fromLTRB(
                            16, widget.showWatermarkControls ? 4 : 8, 16, 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Estimated Size:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
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
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (_isExportingJpeg || _isExportingPdf)
                    ? null
                    : () async {
                        if (_previewFiles.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No processed images available to export.')),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        setState(() {
                          _isExportingJpeg = true;
                          _isExportingPdf = false;
                        });

                        try {
                          final outputDir =
                              await StorageService.getPublicDirectory(
                            folderName: widget.folderName,
                          );
                          final savedFiles = <File>[];

                          for (int i = 0; i < _previewFiles.length; i++) {
                            final sourceFile = _previewFiles[i];
                            final compressedFile =
                                await CompressionService.compressImage(
                              sourceFile,
                              _selectedQuality,
                            );
                            final outputPath = p.join(
                              outputDir.path,
                              '${widget.docTitle.replaceAll(RegExp(r"[^A-Za-z0-9._-]"), '_')}_${i + 1}.jpg',
                            );
                            final exportedFile = File(outputPath);
                            await exportedFile.writeAsBytes(
                              await compressedFile.readAsBytes(),
                            );
                            savedFiles.add(exportedFile);
                          }

                          if (!mounted) return;
                          if (savedFiles.isNotEmpty) {
                            await Share.shareXFiles(
                              savedFiles
                                  .map((file) => XFile(file.path))
                                  .toList(),
                              subject: '${widget.docTitle} JPEG Export',
                            );
                          }

                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Exported ${savedFiles.length} JPEG file${savedFiles.length == 1 ? '' : 's'}.')),
                          );
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('JPEG export failed.')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isExportingJpeg = false);
                          }
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isExportingJpeg
                      ? Colors.grey.shade500
                      : ((_isExportingJpeg || _isExportingPdf)
                          ? Colors.grey.shade500
                          : const Color(0xFF00A86B)),
                  side: BorderSide(
                    color: _isExportingJpeg
                        ? Colors.grey.shade400
                        : ((_isExportingJpeg || _isExportingPdf)
                            ? Colors.grey.shade400
                            : const Color(0xFF00A86B)),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isExportingJpeg
                    ? const Text("Exporting...",
                        style: TextStyle(fontWeight: FontWeight.bold))
                    : const Text("Export JPEG",
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (_isExportingJpeg || _isExportingPdf)
                    ? null
                    : () async {
                        if (_previewFiles.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No processed images available to export.')),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        setState(() {
                          _isExportingPdf = true;
                          _isExportingJpeg = false;
                        });

                        try {
                          final pdfFile = await PdfService.generatePdf(
                            _previewFiles,
                            widget.docTitle,
                            folderName: widget.folderName,
                          );

                          if (!mounted) return;
                          await Share.shareXFiles(
                            [XFile(pdfFile.path)],
                            subject: '${widget.docTitle} PDF Export',
                          );

                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('PDF exported successfully.')),
                          );
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('PDF export failed.')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isExportingPdf = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isExportingPdf
                      ? Colors.grey.shade400
                      : ((_isExportingJpeg || _isExportingPdf)
                          ? Colors.grey.shade400
                          : const Color(0xFF00A86B)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isExportingPdf
                    ? const Text("Exporting...",
                        style: TextStyle(fontWeight: FontWeight.bold))
                    : const Text("Export PDF",
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
