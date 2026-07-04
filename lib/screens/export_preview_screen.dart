import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../services/ad_service.dart';
import '../services/compression_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/watermark_service.dart';
import '../services/document_enhancer_service.dart';

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

  // Filter selection for live document enhancement.
  String _selectedFilterMode = "Magic Color";

  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _selectedWatermarkColor = widget.initialColor;
    _selectedOpacity = widget.initialOpacity;
    _calculateSize();
    _generateLivePreviews();
    AdService.loadInterstitialAd();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Generates the current preview from the original input files.
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
            if (_selectedFilterMode == "Original") {
              processedFile = originalFile;
            } else {
              processedFile = await DocumentEnhancerService.enhanceImage(
                originalFile,
                mode: _selectedFilterMode,
              );
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
      setState(() => _estimatedSizeText = CompressionService.formatBytes(bytes));
    }
  }

  void _openImageZoom(File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
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

  // ignore: unused_element
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

  // ignore: unused_element
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
              color: isSelected ? const Color(0xFF00A86B) : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              modeName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF00A86B) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper stubs for edit toolbar operations
  void _handleAddPage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Add Page functionality (stub)")),
    );
  }

  void _handleCrop() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Crop & Rotate functionality (stub)")),
    );
  }

  void _handleFilter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Filter functionality (stub)")),
    );
  }

  void _handleClean() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Clean functionality (stub)")),
    );
  }

  void _handleRetake() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Retake functionality (stub)")),
    );
  }

  void _handleDelete() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Delete functionality (stub)")),
    );
  }

  // Export handlers
  Future<void> _exportJpeg() async {
    if (_previewFiles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No processed images available to export.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isExportingJpeg = true;
      _isExportingPdf = false;
    });

    try {
      final outputDir = await StorageService.getPublicDirectory(
        folderName: widget.folderName,
      );
      final savedFiles = <File>[];

      for (int i = 0; i < _previewFiles.length; i++) {
        final sourceFile = _previewFiles[i];
        final compressedFile = await CompressionService.compressImage(
          sourceFile,
          _selectedQuality,
        );
        final outputPath = p.join(
          outputDir.path,
          '${widget.docTitle.replaceAll(RegExp(r"[^A-Za-z0-9._-]"), '_')}_${i + 1}.jpg',
        );
        final exportedFile = File(outputPath);
        await exportedFile.writeAsBytes(await compressedFile.readAsBytes());
        savedFiles.add(exportedFile);
      }

      if (!mounted) return;
      if (savedFiles.isNotEmpty) {
        await Share.shareXFiles(
          savedFiles.map((file) => XFile(file.path)).toList(),
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
          const SnackBar(content: Text('JPEG export failed.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingJpeg = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_previewFiles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No processed images available to export.')),
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
        const SnackBar(content: Text('PDF exported successfully.')),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('PDF export failed.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  // Done Modal Bottom Sheet
  void _showExportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Export Options",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.showWatermarkControls) ...[
                      const Text(
                        "Watermark Style",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSheetColorChip(Colors.grey, "Grey", sheetState),
                          const SizedBox(width: 8),
                          _buildSheetColorChip(Colors.blue, "Blue", sheetState),
                          const SizedBox(width: 8),
                          _buildSheetColorChip(Colors.red, "Red", sheetState),
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
                              color: Colors.white70,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF00A86B),
                                inactiveTrackColor: Colors.grey.shade800,
                                thumbColor: const Color(0xFF00A86B),
                                overlayColor:
                                    const Color(0xFF00A86B).withValues(alpha: 0.2),
                                tickMarkShape: const RoundSliderTickMarkShape(
                                    tickMarkRadius: 2.5),
                                activeTickMarkColor: const Color(0xFF00A86B),
                                inactiveTickMarkColor: Colors.grey.shade600,
                              ),
                              child: Slider(
                                value: _selectedOpacity,
                                min: 0.10,
                                max: 0.80,
                                divisions: 7,
                                label: _selectedOpacity.toStringAsFixed(2),
                                onChanged: (newValue) {
                                  sheetState(() {
                                    _selectedOpacity = newValue;
                                  });
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
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      "Size Optimization",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<CompressionQuality>(
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                            (states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF00A86B);
                              }
                              return Colors.grey.shade800;
                            },
                          ),
                          foregroundColor:
                              WidgetStateProperty.all(Colors.white),
                        ),
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
                          sheetState(() {
                            _selectedQuality = newSelection.first;
                          });
                          setState(() {
                            _selectedQuality = newSelection.first;
                          });
                          _calculateSize().then((_) {
                            sheetState(() {});
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Estimated Size:",
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _estimatedSizeText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00A86B),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_isExportingJpeg || _isExportingPdf)
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    await _exportJpeg();
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00A86B),
                              side: const BorderSide(
                                  color: Color(0xFF00A86B), width: 1.5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Export JPEG",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isExportingJpeg || _isExportingPdf)
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    await _exportPdf();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A86B),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Export PDF",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetColorChip(
      Color color, String label, StateSetter sheetState) {
    final isSelected = _selectedWatermarkColor == color;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isLiveUpdating) return;
          sheetState(() {
            _selectedWatermarkColor = color;
          });
          setState(() {
            _selectedWatermarkColor = color;
          });
          _generateLivePreviews();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.grey.shade900,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade700,
              width: isSelected ? 2 : 1,
            ),
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
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Horizontal Thumbnail strip
  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _previewFiles.length + 1,
        itemBuilder: (context, index) {
          if (index == _previewFiles.length) {
            return GestureDetector(
              onTap: _handleAddPage,
              child: Container(
                width: 60,
                margin:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.grey.shade700, width: 1),
                ),
                child:
                    const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            );
          }

          final isSelected = index == _currentPageIndex;
          final thumbnailFile = _previewFiles[index];

          return GestureDetector(
            onTap: () {
              setState(() => _currentPageIndex = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 60,
              margin:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF93C5FD)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  thumbnailFile,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Toolbar button
  Widget _buildToolbarButton(
      IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Edit Toolbar
  Widget _buildBottomToolbar() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarButton(Icons.crop_rotate, "Crop & Rotate", _handleCrop),
          _buildToolbarButton(Icons.auto_fix_high, "Filter", _handleFilter),
          _buildToolbarButton(
              Icons.cleaning_services_outlined, "Clean", _handleClean),
          _buildToolbarButton(
              Icons.camera_alt_outlined, "Retake", _handleRetake),
          _buildToolbarButton(Icons.delete_outline, "Delete", _handleDelete),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Preview",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: SizedBox(
                height: 36,
                child: TextButton(
                  onPressed: () => _showExportBottomSheet(context),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF93C5FD),
                    foregroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    "Done",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main image preview
            Expanded(
              child: Stack(
                children: [
                  _previewFiles.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00A86B)))
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentPageIndex = index);
                          },
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
                                        color: Colors.black54,
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
                                          color: Colors.black,
                                          child: Image.file(currentFile,
                                              fit: BoxFit.contain),
                                        ),
                                      ),
                                      // Enhance/Magic floating button
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: _handleFilter,
                                          child: const CircleAvatar(
                                            radius: 20,
                                            backgroundColor:
                                                Color(0xFF93C5FD),
                                            child: Icon(Icons.auto_awesome,
                                                color: Color(0xFF1E3A8A),
                                                size: 20),
                                          ),
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
                      color: Colors.black38,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00A86B)),
                      ),
                    ),
                ],
              ),
            ),

            // Page Indicator
            if (_previewFiles.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "${_currentPageIndex + 1}/${_previewFiles.length}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],

            // Horizontal Thumbnail Strip
            if (_previewFiles.isNotEmpty) ...[
              _buildThumbnailStrip(),
              const SizedBox(height: 8),
            ],

            // Bottom Toolbar
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }
}
