import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/compression_service.dart';
import '../services/document_enhancer_service.dart';
import '../services/esign_service.dart';
import '../services/id_card_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_to_image_service.dart';
import '../services/watermark_service.dart';
import 'export_preview_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final ImagePicker _picker = ImagePicker();

  // Tool 1: Batch Gallery Import
  Future<void> _handleBatchImport() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty && mounted) {
      final imagePaths = images.map((e) => e.path).toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportPreviewScreen(
            imagePaths: imagePaths,
            docTitle: "Gallery_Batch_${DateTime.now().millisecondsSinceEpoch}",
          ),
        ),
      );
    }
  }

  // Tool 2: Standalone Image Compressor
  Future<void> _handleStandaloneCompressor() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final sourceFile = File(image.path);
      showDialog(
        context: context,
        builder: (context) => _CompressorDialog(sourceFile: sourceFile),
      );
    }
  }

  // Tool 3: Gallery OCR
  Future<void> _handleGalleryOcr() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final text = await OcrService.extractTextFromImages([image.path]);

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Extracted Text (OCR)"),
            content: SingleChildScrollView(
              child: SelectableText(
                text.isEmpty ? "No readable text found in image." : text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              if (text.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Text copied to clipboard!")),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Color(0xFF00A86B)),
                  label: const Text("Copy Text",
                      style: TextStyle(color: Color(0xFF00A86B))),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }
    }
  }

  // Tool 4: Gallery ID Card Combiner
  Future<void> _handleIdCardCombiner() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Select FRONT side image from gallery...")),
    );
    final XFile? front = await _picker.pickImage(source: ImageSource.gallery);
    if (front == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Now select BACK side image from gallery...")),
      );
    }
    final XFile? back = await _picker.pickImage(source: ImageSource.gallery);
    if (back == null) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final mergedFile = await IdCardService.mergeIdCardImages(
        File(front.path), File(back.path));

    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportPreviewScreen(
            imagePaths: [mergedFile.path],
            docTitle:
                "Gallery_ID_Card_${DateTime.now().millisecondsSinceEpoch}",
          ),
        ),
      );
    }
  }

  // Tool 5: PDF to Image Converter
  Future<void> _handlePdfToImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfFile = File(result.files.single.path!);
      final extractedImages =
          await PdfToImageService.convertPdfToImages(pdfFile);

      if (mounted) {
        Navigator.pop(context);
        if (extractedImages.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExportPreviewScreen(
                imagePaths: extractedImages.map((e) => e.path).toList(),
                docTitle: "PDF_Pages_${DateTime.now().millisecondsSinceEpoch}",
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("No pages could be extracted from PDF.")),
          );
        }
      }
    }
  }

  // Tool 6: Smart Document Enhancer
  Future<void> _handleDocumentEnhancer() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final enhancedFile =
          await DocumentEnhancerService.enhanceImage(File(image.path));

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExportPreviewScreen(
              imagePaths: [enhancedFile.path],
              docTitle: "Magic_Scan_${DateTime.now().millisecondsSinceEpoch}",
            ),
          ),
        );
      }
    }
  }

  // Tool 7: Import & E-Sign
  Future<void> _handleImportESign() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      showDialog(
        context: context,
        builder: (_) => _ESignDialog(sourceFile: File(image.path)),
      );
    }
  }

  // Tool 8: Secure Watermark
  Future<void> _handleSecureWatermark() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      showDialog(
        context: context,
        builder: (_) => _WatermarkDialog(sourceFile: File(image.path)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Gallery Tools",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Smart Gallery Utilities",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                "Process photos & PDFs from your device 100% offline with AI tools.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              _buildToolCard(
                title: "1. Gallery Batch to PDF",
                subtitle:
                    "Select multiple images from gallery and compile into PDF.",
                icon: Icons.picture_as_pdf,
                iconBgColor: const Color(0xFFE6F6F0),
                iconColor: const Color(0xFF00A86B),
                onTap: _handleBatchImport,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "2. Standalone Image Compressor",
                subtitle:
                    "Reduce photo file sizes (MB to KB) with live preview.",
                icon: Icons.compress,
                iconBgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFFFB703),
                onTap: _handleStandaloneCompressor,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "3. Gallery Image OCR",
                subtitle: "Extract and copy printed text using offline ML Kit.",
                icon: Icons.text_snippet,
                iconBgColor: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                onTap: _handleGalleryOcr,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "4. Gallery ID Card Combiner",
                subtitle:
                    "Select Front & Back photos from gallery and merge onto A4.",
                icon: Icons.badge,
                iconBgColor: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                onTap: _handleIdCardCombiner,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "5. PDF to Image Converter",
                subtitle:
                    "Extract all pages from a local PDF file into PNG images.",
                icon: Icons.collections,
                iconBgColor: const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFE11D48),
                onTap: _handlePdfToImage,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "6. Smart Document Enhancer",
                subtitle:
                    "Enhance contrast & brightness for a crisp Magic Color scan look.",
                icon: Icons.auto_fix_high,
                iconBgColor: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                onTap: _handleDocumentEnhancer,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "7. Import & E-Sign",
                subtitle:
                    "Draw and burn your digital signature onto gallery document.",
                icon: Icons.draw,
                iconBgColor: const Color(0xFFE0E7FF),
                iconColor: const Color(0xFF4F46E5),
                onTap: _handleImportESign,
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "8. Secure Watermark",
                subtitle:
                    "Overlay customizable transparent watermark text onto document.",
                icon: Icons.branding_watermark,
                iconBgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                onTap: _handleSecureWatermark,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child:
              Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.3)),
        ),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class _CompressorDialog extends StatefulWidget {
  final File sourceFile;
  const _CompressorDialog({required this.sourceFile});

  @override
  State<_CompressorDialog> createState() => _CompressorDialogState();
}

class _CompressorDialogState extends State<_CompressorDialog> {
  CompressionQuality _quality = CompressionQuality.medium;
  String _originalSizeText = "Calculating...";
  String _compressedSizeText = "Calculating...";
  File? _compressedFile;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _updateSizes();
  }

  Future<void> _updateSizes() async {
    setState(() => _isProcessing = true);
    final origBytes = await widget.sourceFile.length();
    final cmpFile =
        await CompressionService.compressImage(widget.sourceFile, _quality);
    final cmpBytes = await cmpFile.length();

    if (mounted) {
      setState(() {
        _originalSizeText = CompressionService.formatBytes(origBytes);
        _compressedSizeText = CompressionService.formatBytes(cmpBytes);
        _compressedFile = cmpFile;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Compress Image"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Original Size: $_originalSizeText",
              style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          const Text("Select Compression Level:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<CompressionQuality>(
            segments: const [
              ButtonSegment(value: CompressionQuality.low, label: Text("Low")),
              ButtonSegment(
                  value: CompressionQuality.medium, label: Text("Medium")),
              ButtonSegment(
                  value: CompressionQuality.original, label: Text("Original")),
            ],
            selected: {_quality},
            onSelectionChanged: (selection) {
              setState(() => _quality = selection.first);
              _updateSizes();
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F6F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("New Size:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_compressedSizeText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00A86B),
                            fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          onPressed: (_compressedFile == null || _isProcessing)
              ? null
              : () async {
                  await Share.shareXFiles([XFile(_compressedFile!.path)],
                      text: "Compressed Photo");
                  if (context.mounted) Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A86B),
              foregroundColor: Colors.white),
          icon: const Icon(Icons.share, size: 18),
          label: const Text("Save & Share"),
        ),
      ],
    );
  }
}

class _WatermarkDialog extends StatefulWidget {
  final File sourceFile;
  const _WatermarkDialog({required this.sourceFile});

  @override
  State<_WatermarkDialog> createState() => _WatermarkDialogState();
}

class _WatermarkDialogState extends State<_WatermarkDialog> {
  final TextEditingController _textController =
      TextEditingController(text: "CONFIDENTIAL");
  double _opacity = 0.3;
  bool _isProcessing = false;
  Color _selectedColor = Colors.grey;

  Widget _buildDialogColorChip(Color color, String label) {
    final isSelected = _selectedColor == color;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedColor = color),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : Colors.grey.shade100,
            border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(backgroundColor: color, radius: 4),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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
    return AlertDialog(
      title: const Text("Apply Secure Watermark"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: "Watermark Text"),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            const Text("Watermark Color:",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDialogColorChip(Colors.grey, "Grey"),
                const SizedBox(width: 6),
                _buildDialogColorChip(Colors.blue, "Blue"),
                const SizedBox(width: 6),
                _buildDialogColorChip(Colors.red, "Red"),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("Opacity:"),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 0.8,
                    divisions: 7,
                    label: "${(_opacity * 100).round()}%",
                    onChanged: (val) => setState(() => _opacity = val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isProcessing
              ? null
              : () async {
                  final text = _textController.text.trim();
                  if (text.isEmpty) return;
                  setState(() => _isProcessing = true);

                  final wmFile = await WatermarkService.applyWatermark(
                    sourceFile: widget.sourceFile,
                    text: text,
                    opacity: _opacity,
                    watermarkColor: _selectedColor,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportPreviewScreen(
                          imagePaths: [wmFile.path],
                          docTitle:
                              "Watermarked_${DateTime.now().millisecondsSinceEpoch}",
                        ),
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A86B),
              foregroundColor: Colors.white),
          child: const Text("Apply & View"),
        ),
      ],
    );
  }
}

// PREMIUM UPGRADED DRAG & RESIZE E-SIGN DIALOG
class _ESignDialog extends StatefulWidget {
  final File sourceFile;
  const _ESignDialog({required this.sourceFile});

  @override
  State<_ESignDialog> createState() => _ESignDialogState();
}

class _ESignDialogState extends State<_ESignDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  bool _isProcessing = false;

  // Premium State Variables for Moving & Resizing
  bool _isSignaturePlaced = false;
  Offset _boxPosition = const Offset(50, 200);
  double _boxWidth = 220.0;
  double _boxHeight = 110.0;
  Color _selectedSignatureColor = const Color(0xFF0F172A);

  // Hand-drawing pad modal
  void _openSignaturePadModal() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text("Draw Your Signature",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Container(
              width: double.maxFinite,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: GestureDetector(
                onPanStart: (details) {
                  setModalState(() {
                    _currentStroke = [details.localPosition];
                    _strokes.add(_currentStroke!);
                  });
                },
                onPanUpdate: (details) {
                  setModalState(() {
                    _currentStroke?.add(details.localPosition);
                  });
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _SignaturePainter(
                      strokes: _strokes, inkColor: _selectedSignatureColor),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _strokes.clear();
                    _currentStroke = null;
                  });
                  setModalState(() {});
                },
                child: const Text("Clear", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_strokes.isNotEmpty) {
                    setState(() {
                      _isSignaturePlaced = true;
                    });
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
                    foregroundColor: Colors.white),
                child: const Text("Done"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolAction(
      {required IconData icon,
      required String label,
      Color? color,
      required VoidCallback onTap}) {
    final activeColor = color ?? const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: activeColor, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: activeColor,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        appBar: AppBar(
          title: const Text("Import & E-Sign",
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF00A86B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Image Viewport Layer
              Expanded(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Stack(
                      children: [
                        Image.file(widget.sourceFile, fit: BoxFit.contain),
                        if (_isSignaturePlaced)
                          Positioned(
                            left: _boxPosition.dx,
                            top: _boxPosition.dy < 0 ? 0 : _boxPosition.dy,
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      _boxPosition += details.delta;
                                    });
                                  },
                                  child: Container(
                                    width: _boxWidth,
                                    height: _boxHeight,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFF00A86B),
                                        style: BorderStyle.solid,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.fill,
                                      child: SizedBox(
                                        width: 300,
                                        height: 150,
                                        child: CustomPaint(
                                          painter: _SignaturePainter(
                                              strokes: _strokes,
                                              inkColor:
                                                  _selectedSignatureColor),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        _boxWidth += details.delta.dx;
                                        _boxHeight += details.delta.dy;
                                        if (_boxWidth < 80) _boxWidth = 80;
                                        if (_boxHeight < 40) _boxHeight = 40;
                                      });
                                    },
                                    child: const CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Color(0xFF00A86B),
                                      child: Icon(Icons.open_in_full,
                                          size: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Bottom CamScanner Tools Controls
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12, blurRadius: 10, spreadRadius: 1)
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Signature Tools",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildToolAction(
                          icon: Icons.border_color,
                          label: _isSignaturePlaced ? "Redraw" : "Add Sign",
                          onTap: _openSignaturePadModal,
                        ),
                        _buildToolAction(
                          icon: Icons.palette,
                          label: "Blue Ink",
                          color: _selectedSignatureColor == Colors.blue
                              ? const Color(0xFF00A86B)
                              : null,
                          onTap: () => setState(
                              () => _selectedSignatureColor = Colors.blue),
                        ),
                        _buildToolAction(
                          icon: Icons.draw,
                          label: "Black Ink",
                          color:
                              _selectedSignatureColor == const Color(0xFF0F172A)
                                  ? const Color(0xFF00A86B)
                                  : null,
                          onTap: () => setState(() => _selectedSignatureColor =
                              const Color(0xFF0F172A)),
                        ),
                        _buildToolAction(
                          icon: Icons.delete_outline,
                          label: "Remove",
                          onTap: () => setState(() {
                            _strokes.clear();
                            _isSignaturePlaced = false;
                          }),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.0),
                      child: Divider(height: 1, thickness: 0.5),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Cancel",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    if (!_isSignaturePlaced ||
                                        _strokes.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "Please place a signature first!"),
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() => _isProcessing = true);

                                    final signedFile =
                                        await ESignService.applySignature(
                                      widget.sourceFile,
                                      _strokes,
                                      const Size(360, 600),
                                      boxPosition: _boxPosition,
                                      boxSize: Size(_boxWidth, _boxHeight),
                                      inkColor: _selectedSignatureColor,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExportPreviewScreen(
                                            imagePaths: [signedFile.path],
                                            docTitle:
                                                "Signed_${DateTime.now().millisecondsSinceEpoch}",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A86B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text(
                              "Save & Export",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color inkColor;

  _SignaturePainter({required this.strokes, required this.inkColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = inkColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
