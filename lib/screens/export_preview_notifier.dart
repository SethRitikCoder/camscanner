import 'dart:io';
import 'package:flutter/material.dart';
import '../services/compression_service.dart';
import '../services/document_enhancer_service.dart';
import '../services/watermark_service.dart';
import '../services/ad_service.dart';

class ExportPreviewNotifier extends ChangeNotifier {
  // Constructor arguments (mirroring ExportPreviewScreen)
  final List<String> imagePaths;
  final String docTitle;
  final String? folderName;
  final Color initialColor;
  final double initialOpacity;
  final bool isEnhancerFlow;
  final bool isPdfConvertorFlow;
  final bool showWatermarkControls;
  final String watermarkText;

  // State fields
  List<File> previewFiles = [];
  bool isLiveUpdating = false;
  CompressionQuality selectedQuality = CompressionQuality.medium;
  String estimatedSizeText = "Calculating...";
  bool isExportingJpeg = false;
  bool isExportingPdf = false;
  Color selectedWatermarkColor;
  double selectedOpacity;
  String selectedFilterMode = "Magic Color";

  ExportPreviewNotifier({
    required this.imagePaths,
    required this.docTitle,
    this.folderName,
    this.initialColor = Colors.grey,
    this.initialOpacity = 0.30,
    this.isEnhancerFlow = false,
    this.isPdfConvertorFlow = false,
    this.showWatermarkControls = false,
    this.watermarkText = "DocScanner Pro",
  })  : selectedWatermarkColor = initialColor,
        selectedOpacity = initialOpacity {
    _calculateSize();
    generateLivePreviews();
    AdService.loadInterstitialAd();
  }

  // Generate live previews based on current settings
  Future<void> generateLivePreviews() async {
    if (isLiveUpdating) return;
    isLiveUpdating = true;
    notifyListeners();
    try {
      List<File> temp = [];
      for (final path in imagePaths) {
        final original = File(path);
        if (!original.existsSync()) continue;
        File processed = original;
        if (isEnhancerFlow) {
          if (selectedFilterMode == "Original") {
            processed = original;
          } else {
            processed = await DocumentEnhancerService.enhanceImage(
              original,
              mode: selectedFilterMode,
            );
          }
        } else if (showWatermarkControls) {
          processed = await WatermarkService.applyWatermark(
            sourceFile: original,
            text: watermarkText,
            opacity: selectedOpacity,
            watermarkColor: selectedWatermarkColor,
          );
        }
        temp.add(processed);
      }
      previewFiles = temp;
    } catch (_) {
      // silently ignore errors
    }
    isLiveUpdating = false;
    notifyListeners();
  }

  Future<void> _calculateSize() async {
    estimatedSizeText = "Calculating...";
    notifyListeners();
    final bytes = await CompressionService.estimateCompressedSize(
        imagePaths, selectedQuality);
    estimatedSizeText = CompressionService.formatBytes(bytes);
    notifyListeners();
  }

  // Interaction helpers
  void updateWatermarkColor(Color c) {
    selectedWatermarkColor = c;
    notifyListeners();
    generateLivePreviews();
  }

  void updateOpacity(double o) {
    selectedOpacity = o;
    notifyListeners();
  }

  void updateFilterMode(String mode) {
    if (isLiveUpdating || selectedFilterMode == mode) return;
    selectedFilterMode = mode;
    notifyListeners();
    generateLivePreviews();
  }

  void updateQuality(CompressionQuality q) {
    selectedQuality = q;
    notifyListeners();
    _calculateSize();
  }

  void setExportingJpeg(bool v) {
    isExportingJpeg = v;
    notifyListeners();
  }

  void setExportingPdf(bool v) {
    isExportingPdf = v;
    notifyListeners();
  }
}
