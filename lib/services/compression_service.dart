import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

enum CompressionQuality { low, medium, original }

class CompressionService {
  static Future<File> compressImage(File sourceFile, CompressionQuality quality) async {
    if (quality == CompressionQuality.original) {
      return sourceFile;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = join(tempDir.path, 'cmp_${DateTime.now().millisecondsSinceEpoch}_${basename(sourceFile.path)}');

      int qualityPercent;
      int minWidth;
      int minHeight;

      switch (quality) {
        case CompressionQuality.low:
          qualityPercent = 35;
          minWidth = 800;
          minHeight = 1200;
          break;
        case CompressionQuality.medium:
          qualityPercent = 65;
          minWidth = 1200;
          minHeight = 1800;
          break;
        case CompressionQuality.original:
          qualityPercent = 100;
          minWidth = 1920;
          minHeight = 2560;
          break;
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        targetPath,
        quality: qualityPercent,
        minWidth: minWidth,
        minHeight: minHeight,
      );

      if (result != null) {
        return File(result.path);
      }
    } catch (e) {
      // Fallback to original sourceFile on any compression error
    }
    return sourceFile;
  }

  static Future<int> estimateCompressedSize(List<String> imagePaths, CompressionQuality quality) async {
    int totalBytes = 0;
    for (String path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        final rawLength = await file.length();
        if (quality == CompressionQuality.original) {
          totalBytes += rawLength;
        } else if (quality == CompressionQuality.low) {
          totalBytes += (rawLength * 0.35).round();
        } else if (quality == CompressionQuality.medium) {
          totalBytes += (rawLength * 0.65).round();
        }
      }
    }
    return totalBytes;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    int i = (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / (1 << (i * 10));
    return "${num.toStringAsFixed(2)} ${suffixes[i]}";
  }
}
