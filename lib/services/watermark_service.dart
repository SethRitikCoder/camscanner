import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WatermarkService {
  /// Programmatically overlays a premium repeated grid watermark text over an image offline.
  static Future<File> applyWatermark(
      File sourceFile, String text, double opacity) async {
    final bytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final double width = image.width.toDouble();
    final double height = image.height.toDouble();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // 1. Draw original image without any loss
    canvas.drawImage(
        image, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    // 2. Prepare Premium Repeated/Tiled Diagonal Text
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text.toUpperCase(),
        style: TextStyle(
          color: Colors.red
              .withValues(alpha: opacity), // Keeps your dynamic opacity intact
          fontSize: width *
              0.045, // Optimized size for professional repeating pattern
          fontWeight: FontWeight.bold,
          letterSpacing: 3.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Define grid spacing based on image and text dimensions
    final double stepX =
        textPainter.width + (width * 0.15); // Horizontal gap between text
    final double stepY =
        textPainter.height + (height * 0.12); // Vertical gap between rows

    canvas.save();

    // Rotate canvas around the center to keep all grid texts perfectly aligned diagonally
    canvas.translate(width / 2, height / 2);
    canvas.rotate(-0.785398); // Exact -45 degree rotation like CamScanner
    canvas.translate(-width / 2, -height / 2);

    // Cover an extended bound area to ensure corners are fully filled after rotation
    for (double x = -width * 0.5; x < width * 1.5; x += stepX) {
      for (double y = -height * 0.5; y < height * 1.5; y += stepY) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();

    // 3. Finalize and save without breaking the high-quality pipeline
    final ui.Picture picture = recorder.endRecording();
    final ui.Image watermarkedImage =
        await picture.toImage(image.width, image.height);
    final byteData =
        await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final watermarkedFile = File(p.join(
        tempDir.path, 'wm_${DateTime.now().millisecondsSinceEpoch}.png'));
    await watermarkedFile.writeAsBytes(byteData!.buffer.asUint8List());

    image.dispose();
    watermarkedImage.dispose();

    return watermarkedFile;
  }
}
