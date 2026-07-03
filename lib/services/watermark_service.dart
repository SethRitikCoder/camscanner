import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WatermarkService {
  /// Programmatically overlays a premium repeated grid watermark text over an image with custom color.
  static Future<File> applyWatermark({
    required File sourceFile,
    required String text,
    required double opacity,
    required Color watermarkColor, // Naya dynamic color parameter
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final double width = image.width.toDouble();
    final double height = image.height.toDouble();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // 1. Original image draw ki
    canvas.drawImage(
        image, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    // 2. Tiled Text setup dynamic color ke sath
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text.toUpperCase(),
        style: TextStyle(
          color: watermarkColor.withValues(
              alpha: opacity), // Ab ye dynamic rang lega!
          fontSize: width * 0.045,
          fontWeight: FontWeight.bold,
          letterSpacing: 3.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final double stepX = textPainter.width + (width * 0.15);
    final double stepY = textPainter.height + (height * 0.12);

    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.rotate(-0.785398); // -45 degree dynamic rotation
    canvas.translate(-width / 2, -height / 2);

    for (double x = -width * 0.5; x < width * 1.5; x += stepX) {
      for (double y = -height * 0.5; y < height * 1.5; y += stepY) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();

    // 3. Image save pipeline
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
