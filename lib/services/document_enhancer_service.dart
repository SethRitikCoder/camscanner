import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DocumentEnhancerService {
  /// Applies a Magic Color / High Contrast enhancement filter to a document image offline.
  static Future<File> enhanceImage(File sourceFile) async {
    final bytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

    // High contrast & brightness matrix for "Magic Color" scan look
    const double contrast = 1.35;
    const double brightness = 15.0;
    const ColorFilter magicColorFilter = ColorFilter.matrix(<double>[
      contrast, 0, 0, 0, brightness,
      0, contrast, 0, 0, brightness,
      0, 0, contrast, 0, brightness,
      0, 0, 0, 1, 0,
    ]);

    final Paint paint = Paint()
      ..colorFilter = magicColorFilter
      ..filterQuality = FilterQuality.high;

    canvas.drawImage(image, Offset.zero, paint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image enhancedImage = await picture.toImage(image.width, image.height);
    final byteData = await enhancedImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final enhancedFile = File(p.join(tempDir.path, 'magic_${DateTime.now().millisecondsSinceEpoch}.png'));
    await enhancedFile.writeAsBytes(byteData!.buffer.asUint8List());

    image.dispose();
    enhancedImage.dispose();

    return enhancedFile;
  }
}
