import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WatermarkService {
  /// Programmatically overlays rotated watermark text over an image offline.
  static Future<File> applyWatermark(File sourceFile, String text, double opacity) async {
    final bytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final double width = image.width.toDouble();
    final double height = image.height.toDouble();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Draw original image
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    // Prepare rotated diagonal text
    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.rotate(-0.45); // ~25 degree angle

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text.toUpperCase(),
        style: TextStyle(
          color: Colors.red.withValues(alpha: opacity),
          fontSize: width * 0.08,
          fontWeight: FontWeight.bold,
          letterSpacing: 4.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image watermarkedImage = await picture.toImage(image.width, image.height);
    final byteData = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final watermarkedFile = File(p.join(tempDir.path, 'wm_${DateTime.now().millisecondsSinceEpoch}.png'));
    await watermarkedFile.writeAsBytes(byteData!.buffer.asUint8List());

    image.dispose();
    watermarkedImage.dispose();

    return watermarkedFile;
  }
}
