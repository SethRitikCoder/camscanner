import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/compression_service.dart';
import '../services/esign_service.dart';
import 'export_preview_screen.dart';
import 'tools_notifier.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ToolsNotifier>(
      create: (_) => ToolsNotifier(),
      child: const _ToolsScreenContent(),
    );
  }
}

class _ToolsScreenContent extends StatelessWidget {
  const _ToolsScreenContent();

  Future<void> _handleBatchImport(BuildContext context, ToolsNotifier notifier) async {
    final imagePaths = await notifier.pickBatchImages();
    if (imagePaths != null && context.mounted) {
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

  Future<void> _handleStandaloneCompressor(BuildContext context, ToolsNotifier notifier) async {
    final file = await notifier.pickSingleImage();
    if (file != null && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => ChangeNotifierProvider.value(
          value: notifier,
          child: _CompressorDialog(sourceFile: file),
        ),
      );
    }
  }

  void _showPremiumOcrBottomSheet(BuildContext context, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Extracted Text (OCR)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: Container(
                  color: Colors.grey.shade50,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: SelectableText(
                      text.isNotEmpty
                          ? text
                          : "No readable text found in image.",
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w400,
                      ),
                      cursorColor: const Color(0xFF00A86B),
                      showCursor: true,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: text.isEmpty
                              ? null
                              : () {
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Copied to clipboard successfully!"),
                                      backgroundColor: Color(0xFF00A86B),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.copy_all, size: 20),
                          label: const Text(
                            "Copy All Text",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A86B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleGalleryOcr(BuildContext context, ToolsNotifier notifier) async {
    final file = await notifier.pickSingleImage();
    if (file != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final text = await notifier.runOcr(file.path);

      if (context.mounted) {
        Navigator.pop(context);
        _showPremiumOcrBottomSheet(context, text);
      }
    }
  }

  Future<void> _handleIdCardCombiner(BuildContext context, ToolsNotifier notifier) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Select FRONT side image from gallery...")),
    );
    final front = await notifier.pickSingleImage();
    if (front == null) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Now select BACK side image from gallery...")),
      );
    }
    final back = await notifier.pickSingleImage();
    if (back == null) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final mergedFile = await notifier.mergeIdCard(front, back);

    if (context.mounted) {
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

  Future<void> _handlePdfToImage(BuildContext context, ToolsNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfFile = File(result.files.single.path!);
      final extractedImages = await notifier.convertPdf(pdfFile);

      if (context.mounted) {
        Navigator.pop(context);
        if (extractedImages.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExportPreviewScreen(
                imagePaths: extractedImages.map((e) => e.path).toList(),
                docTitle: "PDF_Pages_${DateTime.now().millisecondsSinceEpoch}",
                isPdfConvertorFlow: true,
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

  Future<void> _handleDocumentEnhancer(BuildContext context, ToolsNotifier notifier) async {
    final file = await notifier.pickSingleImage();
    if (file != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportPreviewScreen(
            imagePaths: [file.path],
            docTitle: "Magic_Scan_${DateTime.now().millisecondsSinceEpoch}",
            isEnhancerFlow: true,
          ),
        ),
      );
    }
  }

  Future<void> _handleImportESign(BuildContext context, ToolsNotifier notifier) async {
    final file = await notifier.pickSingleImage();
    if (file != null && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => ChangeNotifierProvider.value(
          value: notifier,
          child: _ESignDialog(sourceFile: file),
        ),
      );
    }
  }

  Future<void> _handleSecureWatermark(BuildContext context, ToolsNotifier notifier) async {
    final file = await notifier.pickSingleImage();
    if (file != null && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => ChangeNotifierProvider.value(
          value: notifier,
          child: _WatermarkDialog(sourceFile: file),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<ToolsNotifier>(context, listen: false);

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
                onTap: () => _handleBatchImport(context, notifier),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "2. Standalone Image Compressor",
                subtitle:
                    "Reduce photo file sizes (MB to KB) with live preview.",
                icon: Icons.compress,
                iconBgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFFFB703),
                onTap: () => _handleStandaloneCompressor(context, notifier),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "3. Gallery Image OCR",
                subtitle: "Extract and copy printed text using offline ML Kit.",
                icon: Icons.text_snippet,
                iconBgColor: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                onTap: () => _handleGalleryOcr(context, notifier),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "4. Gallery ID Card Combiner",
                subtitle:
                    "Select Front & Back photos from gallery and merge onto A4.",
                icon: Icons.badge,
                iconBgColor: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                onTap: () => _handleIdCardCombiner(context, notifier),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "5. PDF to Image Converter",
                subtitle:
                    "Extract all pages from a local PDF file into PNG images.",
                icon: Icons.collections,
                iconBgColor: const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFE11D48),
                onTap: () => _handlePdfToImage(context, notifier),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "6. Smart Document Enhancer",
                subtitle:
                    "Enhance contrast & brightness for a crisp Magic Color scan look.",
                icon: Icons.auto_fix_high,
                iconBgColor: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                onTap: () => _handleDocumentEnhancer(context, notifier),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "7. Import & E-Sign",
                subtitle:
                    "Draw and burn your digital signature onto gallery document.",
                icon: Icons.draw,
                iconBgColor: const Color(0xFFE0E7FF),
                iconColor: const Color(0xFF4F46E5),
                onTap: () => _handleImportESign(context, notifier),
              ),
              const SizedBox(height: 12),
              _buildToolCard(
                title: "8. Secure Watermark",
                subtitle:
                    "Overlay customizable transparent watermark text onto document.",
                icon: Icons.branding_watermark,
                iconBgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                onTap: () => _handleSecureWatermark(context, notifier),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = Provider.of<ToolsNotifier>(context, listen: false);
      notifier.resetCompressor();
      notifier.updateCompressorSizes(widget.sourceFile);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ToolsNotifier>(
      builder: (context, notifier, child) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Compress Image"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Original Size: ${notifier.compressorOriginalSize}",
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              const Text("Select Compression Level:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<CompressionQuality>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: CompressionQuality.low,
                      label: Text("Low"),
                    ),
                    ButtonSegment(
                      value: CompressionQuality.medium,
                      label: Text("Medium"),
                    ),
                    ButtonSegment(
                      value: CompressionQuality.original,
                      label: Text("Original"),
                    ),
                  ],
                  selected: {notifier.compressionQuality},
                  onSelectionChanged: (Set<CompressionQuality> newSelection) {
                    notifier.setCompressionQuality(newSelection.first, widget.sourceFile);
                  },
                ),
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
                    notifier.isCompressing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(notifier.compressorCompressedSize,
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
              onPressed: (notifier.compressorCompressedFile == null || notifier.isCompressing)
                  ? null
                  : () async {
                      await Share.shareXFiles([XFile(notifier.compressorCompressedFile!.path)],
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
      },
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
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final notifier = Provider.of<ToolsNotifier>(context, listen: false);
    notifier.resetWatermark();
    _textController = TextEditingController(text: notifier.watermarkText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _buildDialogColorChip(ToolsNotifier notifier, Color color, String label) {
    final isSelected = notifier.watermarkColor == color;
    return Expanded(
      child: GestureDetector(
        onTap: () => notifier.setWatermarkColor(color),
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
    return Consumer<ToolsNotifier>(
      builder: (context, notifier, child) {
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
                  onChanged: (val) => notifier.setWatermarkText(val),
                ),
                const SizedBox(height: 16),
                const Text("Watermark Color:",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildDialogColorChip(notifier, Colors.grey, "Grey"),
                    const SizedBox(width: 6),
                    _buildDialogColorChip(notifier, Colors.blue, "Blue"),
                    const SizedBox(width: 6),
                    _buildDialogColorChip(notifier, Colors.red, "Red"),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Opacity:"),
                    Expanded(
                      child: Slider(
                        value: notifier.watermarkOpacity,
                        min: 0.1,
                        max: 0.8,
                        divisions: 7,
                        label: "${(notifier.watermarkOpacity * 100).round()}%",
                        onChanged: (val) => notifier.setWatermarkOpacity(val),
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
              onPressed: () {
                final text = _textController.text.trim();
                if (text.isEmpty) return;

                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExportPreviewScreen(
                      imagePaths: [widget.sourceFile.path],
                      docTitle:
                          "Watermarked_${DateTime.now().millisecondsSinceEpoch}",
                      initialColor: notifier.watermarkColor,
                      initialOpacity: notifier.watermarkOpacity,
                      showWatermarkControls: true,
                      watermarkText: text,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A86B),
                  foregroundColor: Colors.white),
              child: const Text("Apply & View"),
            ),
          ],
        );
      },
    );
  }
}

class _ESignDialog extends StatefulWidget {
  final File sourceFile;
  const _ESignDialog({required this.sourceFile});

  @override
  State<_ESignDialog> createState() => _ESignDialogState();
}

class _ESignDialogState extends State<_ESignDialog> {
  double _imgWidth = 0;
  double _imgHeight = 0;
  bool _isImageSizeLoaded = false;
  Size _displaySize = const Size(360, 600);
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ToolsNotifier>(context, listen: false).resetESign();
      _loadImageSize();
    });
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await widget.sourceFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      if (mounted) {
        setState(() {
          _imgWidth = image.width.toDouble();
          _imgHeight = image.height.toDouble();
          _isImageSizeLoaded = true;
        });
      }
      image.dispose();
    } catch (e) {
      debugPrint("Failed to load image size: $e");
    }
  }

  void _openSignaturePadModal(BuildContext context, ToolsNotifier notifier) {
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: notifier,
        child: Consumer<ToolsNotifier>(
          builder: (context, notifier, child) {
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
                    notifier.startESignStroke(details.localPosition);
                  },
                  onPanUpdate: (details) {
                    notifier.updateESignStroke(details.localPosition);
                  },
                  onPanEnd: (details) {
                    notifier.endESignStroke();
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SignaturePainter(
                        strokes: notifier.esignStrokes,
                        inkColor: notifier.esignInkColor),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    notifier.clearESignStrokes();
                  },
                  child: const Text("Clear", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (notifier.esignStrokes.isNotEmpty) {
                      notifier.placeESignSignature(true);
                      Navigator.pop(dialogContext);
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
    return Consumer<ToolsNotifier>(
      builder: (context, notifier, child) {
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
                  Expanded(
                    child: Container(
                      color: const Color(0xFF0F172A),
                      child: Center(
                        child: !_isImageSizeLoaded
                            ? const CircularProgressIndicator(color: Color(0xFF00A86B))
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
                                  _displaySize = getDisplayImageSize(containerSize, _imgWidth, _imgHeight);

                                  return SizedBox(
                                    key: _previewKey,
                                    width: _displaySize.width,
                                    height: _displaySize.height,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: Image.file(widget.sourceFile, fit: BoxFit.fill),
                                        ),
                                        if (notifier.isESignSignaturePlaced)
                                          Positioned(
                                            left: notifier.esignBoxPosition.dx - 24,
                                            top: (notifier.esignBoxPosition.dy - 32 < 0) ? 0 : notifier.esignBoxPosition.dy - 32,
                                            child: Transform.rotate(
                                              angle: notifier.esignRotation,
                                              child: SizedBox(
                                                width: notifier.esignBoxWidth + 48,
                                                height: notifier.esignBoxHeight + 56,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    // Bounded Signature Box (Padded Frame)
                                                    Positioned(
                                                      left: 24,
                                                      top: 32,
                                                      child: GestureDetector(
                                                        onPanUpdate: (details) {
                                                          notifier.updateESignBoxPosition(
                                                            details.delta,
                                                            maxSize: _displaySize,
                                                          );
                                                        },
                                                        child: Container(
                                                          width: notifier.esignBoxWidth,
                                                          height: notifier.esignBoxHeight,
                                                          padding: const EdgeInsets.all(6),
                                                          child: CustomPaint(
                                                            painter: _DashedBorderPainter(
                                                              color: const Color(0xFF00A86B),
                                                              strokeWidth: 1.5,
                                                              gap: 5.0,
                                                              dashWidth: 5.0,
                                                            ),
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(4.0),
                                                              child: FittedBox(
                                                                fit: BoxFit.fill,
                                                                child: SizedBox(
                                                                  width: 300,
                                                                  height: 150,
                                                                  child: CustomPaint(
                                                                    painter: _SignaturePainter(
                                                                        strokes: notifier.esignStrokes,
                                                                        inkColor: notifier.esignInkColor),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // Resize Handle (Bottom-Right outside)
                                                    Positioned(
                                                      bottom: 4,
                                                      right: 4,
                                                      child: GestureDetector(
                                                        behavior: HitTestBehavior.opaque,
                                                        onPanUpdate: (details) {
                                                          notifier.updateESignBoxSize(
                                                            details.delta.dx,
                                                            details.delta.dy,
                                                            maxSize: _displaySize,
                                                          );
                                                        },
                                                        child: const Padding(
                                                          padding: EdgeInsets.all(4.0),
                                                          child: CircleAvatar(
                                                            radius: 12,
                                                            backgroundColor: Color(0xFF00A86B),
                                                            child: Icon(Icons.open_in_full,
                                                                size: 14, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // Rotation Handle (Top-Center outside)
                                                    Positioned(
                                                      top: 4,
                                                      left: (notifier.esignBoxWidth / 2) + 24 - 16,
                                                      child: GestureDetector(
                                                        behavior: HitTestBehavior.opaque,
                                                        onPanUpdate: (details) {
                                                          final renderBox = _previewKey.currentContext?.findRenderObject() as RenderBox?;
                                                          if (renderBox != null) {
                                                            final localTouch = renderBox.globalToLocal(details.globalPosition);
                                                            final boxCenter = Offset(
                                                              notifier.esignBoxPosition.dx + notifier.esignBoxWidth / 2,
                                                              notifier.esignBoxPosition.dy + notifier.esignBoxHeight / 2,
                                                            );
                                                            final dx = localTouch.dx - boxCenter.dx;
                                                            final dy = localTouch.dy - boxCenter.dy;
                                                            double angle = atan2(dy, dx) + (pi / 2);
                                                            notifier.updateESignRotation(angle);
                                                          }
                                                        },
                                                        child: const Padding(
                                                          padding: EdgeInsets.all(4.0),
                                                          child: CircleAvatar(
                                                            radius: 12,
                                                            backgroundColor: Colors.blueAccent,
                                                            child: Icon(Icons.rotate_right,
                                                                size: 14, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
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
                              label: notifier.isESignSignaturePlaced ? "Redraw" : "Add Sign",
                              onTap: () => _openSignaturePadModal(context, notifier),
                            ),
                            _buildToolAction(
                              icon: Icons.palette,
                              label: "Blue Ink",
                              color: notifier.esignInkColor == Colors.blue
                                  ? const Color(0xFF00A86B)
                                  : null,
                              onTap: () => notifier.setESignInkColor(Colors.blue),
                            ),
                            _buildToolAction(
                              icon: Icons.draw,
                              label: "Black Ink",
                              color: notifier.esignInkColor == const Color(0xFF0F172A)
                                      ? const Color(0xFF00A86B)
                                      : null,
                              onTap: () => notifier.setESignInkColor(const Color(0xFF0F172A)),
                            ),
                            _buildToolAction(
                              icon: Icons.delete_outline,
                              label: "Remove",
                              onTap: () => notifier.clearESignStrokes(),
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
                                onPressed: notifier.isESignProcessing
                                    ? null
                                    : () async {
                                        if (!notifier.isESignSignaturePlaced ||
                                            notifier.esignStrokes.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  "Please place a signature first!"),
                                            ),
                                          );
                                          return;
                                        }

                                        notifier.setESignProcessing(true);

                                        final signedFile =
                                            await ESignService.applySignature(
                                          widget.sourceFile,
                                          notifier.esignStrokes,
                                          _displaySize,
                                          boxPosition: notifier.esignBoxPosition,
                                          boxSize: Size(notifier.esignBoxWidth, notifier.esignBoxHeight),
                                          inkColor: notifier.esignInkColor,
                                          esignRotation: notifier.esignRotation,
                                        );

                                        if (context.mounted) {
                                          notifier.setESignProcessing(false);
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
      },
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashWidth;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 5.0,
    this.dashWidth = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    _addDashedLine(path, Offset.zero, Offset(size.width, 0));
    _addDashedLine(path, Offset(size.width, 0), Offset(size.width, size.height));
    _addDashedLine(path, Offset(size.width, size.height), Offset(0, size.height));
    _addDashedLine(path, Offset(0, size.height), Offset.zero);

    canvas.drawPath(path, paint);
  }

  void _addDashedLine(Path path, Offset start, Offset end) {
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double distance = sqrt(dx * dx + dy * dy);
    
    final int count = (distance / (dashWidth + gap)).floor();
    
    final double xStep = dx / distance;
    final double yStep = dy / distance;
    
    for (int i = 0; i < count; i++) {
      final double startDist = i * (dashWidth + gap);
      final double endDist = startDist + dashWidth;
      
      path.moveTo(start.dx + xStep * startDist, start.dy + yStep * startDist);
      path.lineTo(start.dx + xStep * endDist, start.dy + yStep * endDist);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.dashWidth != dashWidth;
}

Size getDisplayImageSize(Size constraintSize, double imgWidth, double imgHeight) {
  double imgRatio = imgWidth / imgHeight;
  double constraintRatio = constraintSize.width / constraintSize.height;

  double displayWidth;
  double displayHeight;
  if (imgRatio > constraintRatio) {
    displayWidth = constraintSize.width;
    displayHeight = constraintSize.width / imgRatio;
  } else {
    displayHeight = constraintSize.height;
    displayWidth = constraintSize.height * imgRatio;
  }
  return Size(displayWidth, displayHeight);
}
