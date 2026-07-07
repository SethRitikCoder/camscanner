import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/compression_service.dart';
import '../services/id_card_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_to_image_service.dart';

class ToolsNotifier extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  // --- Compressor State ---
  CompressionQuality compressionQuality = CompressionQuality.medium;
  String compressorOriginalSize = "Calculating...";
  String compressorCompressedSize = "Calculating...";
  File? compressorCompressedFile;
  bool isCompressing = false;

  // --- Watermark State ---
  String watermarkText = "DocScanner Pro";
  double watermarkOpacity = 0.3;
  Color watermarkColor = Colors.grey;

  // --- E-Sign State ---
  final List<List<Offset>> esignStrokes = [];
  List<Offset>? esignCurrentStroke;
  bool isESignSignaturePlaced = false;
  Offset esignBoxPosition = const Offset(50, 200);
  double esignBoxWidth = 220.0;
  double esignBoxHeight = 110.0;
  double esignRotation = 0.0;
  Color esignInkColor = const Color(0xFF0F172A);
  bool isESignProcessing = false;

  // --- General States ---
  bool isGeneralProcessing = false;

  // --- Compressor Methods ---
  Future<void> updateCompressorSizes(File sourceFile) async {
    isCompressing = true;
    notifyListeners();

    try {
      final origBytes = await sourceFile.length();
      final cmpFile = await CompressionService.compressImage(sourceFile, compressionQuality);
      final cmpBytes = await cmpFile.length();

      compressorOriginalSize = CompressionService.formatBytes(origBytes);
      compressorCompressedSize = CompressionService.formatBytes(cmpBytes);
      compressorCompressedFile = cmpFile;
    } catch (e) {
      debugPrint("Compression failed: $e");
    } finally {
      isCompressing = false;
      notifyListeners();
    }
  }

  void setCompressionQuality(CompressionQuality q, File sourceFile) {
    if (compressionQuality == q) return;
    compressionQuality = q;
    notifyListeners();
    updateCompressorSizes(sourceFile);
  }

  void resetCompressor() {
    compressionQuality = CompressionQuality.medium;
    compressorOriginalSize = "Calculating...";
    compressorCompressedSize = "Calculating...";
    compressorCompressedFile = null;
    isCompressing = false;
  }

  // --- Watermark Methods ---
  void setWatermarkText(String text) {
    watermarkText = text;
    notifyListeners();
  }

  void setWatermarkColor(Color color) {
    watermarkColor = color;
    notifyListeners();
  }

  void setWatermarkOpacity(double opacity) {
    watermarkOpacity = opacity;
    notifyListeners();
  }

  void resetWatermark() {
    watermarkText = "DocScanner Pro";
    watermarkOpacity = 0.3;
    watermarkColor = Colors.grey;
  }

  // --- E-Sign Methods ---
  void startESignStroke(Offset position) {
    esignCurrentStroke = [position];
    esignStrokes.add(esignCurrentStroke!);
    notifyListeners();
  }

  void updateESignStroke(Offset position) {
    esignCurrentStroke?.add(position);
    notifyListeners();
  }

  void endESignStroke() {
    esignCurrentStroke = null;
    notifyListeners();
  }

  void clearESignStrokes() {
    esignStrokes.clear();
    esignCurrentStroke = null;
    isESignSignaturePlaced = false;
    notifyListeners();
  }

  void placeESignSignature(bool placed) {
    isESignSignaturePlaced = placed;
    notifyListeners();
  }

  void updateESignBoxPosition(Offset delta, {required Size maxSize}) {
    double left = esignBoxPosition.dx + delta.dx;
    double top = esignBoxPosition.dy + delta.dy;

    if (left < 0) left = 0;
    if (left + esignBoxWidth > maxSize.width) {
      left = maxSize.width - esignBoxWidth;
    }

    if (top < 0) top = 0;
    if (top + esignBoxHeight > maxSize.height) {
      top = maxSize.height - esignBoxHeight;
    }

    esignBoxPosition = Offset(left, top);
    notifyListeners();
  }

  void updateESignBoxSize(double dx, double dy, {required Size maxSize}) {
    const double minWidth = 80.0;
    const double minHeight = 40.0;
    const double startWidth = 220.0;
    const double startHeight = 110.0;
    const double aspectRatio = startWidth / startHeight;

    double newWidth = esignBoxWidth;
    double newHeight = esignBoxHeight;

    if (dx.abs() > dy.abs()) {
      newWidth += dx;
      newHeight = newWidth / aspectRatio;
    } else {
      newHeight += dy;
      newWidth = newHeight * aspectRatio;
    }

    final double maxAllowedWidth = maxSize.width - esignBoxPosition.dx;
    final double maxAllowedHeight = maxSize.height - esignBoxPosition.dy;

    if (newWidth > maxAllowedWidth) {
      newWidth = maxAllowedWidth;
      newHeight = newWidth / aspectRatio;
    }

    if (newHeight > maxAllowedHeight) {
      newHeight = maxAllowedHeight;
      newWidth = newHeight * aspectRatio;
    }

    if (newWidth < minWidth) {
      newWidth = minWidth;
      newHeight = newWidth / aspectRatio;
    }
    if (newHeight < minHeight) {
      newHeight = minHeight;
      newWidth = newHeight * aspectRatio;
    }

    esignBoxWidth = newWidth;
    esignBoxHeight = newHeight;
    notifyListeners();
  }

  void setESignInkColor(Color color) {
    esignInkColor = color;
    notifyListeners();
  }

  void setESignProcessing(bool val) {
    isESignProcessing = val;
    notifyListeners();
  }

  void updateESignRotation(double angle) {
    esignRotation = angle;
    notifyListeners();
  }

  void resetESign() {
    esignStrokes.clear();
    esignCurrentStroke = null;
    isESignSignaturePlaced = false;
    esignBoxPosition = const Offset(50, 200);
    esignBoxWidth = 220.0;
    esignBoxHeight = 110.0;
    esignRotation = 0.0;
    esignInkColor = const Color(0xFF0F172A);
    isESignProcessing = false;
  }

  // --- Picker/Service wrapper handlers ---
  Future<List<String>?> pickBatchImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      return images.map((e) => e.path).toList();
    }
    return null;
  }

  Future<File?> pickSingleImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  Future<String> runOcr(String path) async {
    return await OcrService.extractTextFromImages([path]);
  }

  Future<File> mergeIdCard(File front, File back) async {
    return await IdCardService.mergeIdCardImages(front, back);
  }

  Future<List<File>> convertPdf(File pdfFile) async {
    return await PdfToImageService.convertPdfToImages(pdfFile);
  }
}
