import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ESignService {
  /// Merges drawn signature points onto a document background image offline.
  static Future<File> applySignature(
    File sourceFile,
    List<List<Offset>> strokes,
    Size canvasDisplaySize,
  ) async {
    final bytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final double width = image.width.toDouble();
    final double height = image.height.toDouble();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Draw original background image
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    // Scale drawn stroke points from display widget size to actual image dimensions
    final double scaleX = width / canvasDisplaySize.width;
    final double scaleY = height / canvasDisplaySize.height;

    final Paint strokePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0 * scaleX;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        final p1 = Offset(stroke[i].dx * scaleX, stroke[i].dy * scaleY);
        final p2 = Offset(stroke[i + 1].dx * scaleX, stroke[i + 1].dy * scaleY);
        canvas.drawLine(p1, p2, strokePaint);
      }
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image signedImage = await picture.toImage(image.width, image.height);
    final byteData = await signedImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final signedFile = File(p.join(tempDir.path, 'signed_${DateTime.now().millisecondsSinceEpoch}.png'));
    await signedFile.writeAsBytes(byteData!.buffer.asUint8List());

    image.dispose();
    signedImage.dispose();

    return signedFile;
  }
}
