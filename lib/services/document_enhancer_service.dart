import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DocumentEnhancerService {
  static Future<File> enhanceImage(
    File sourceFile, {
    String mode = 'Magic Color',
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );

    final Paint paint = Paint()
      ..colorFilter = _filterForMode(mode)
      ..filterQuality = FilterQuality.high;

    canvas.drawImage(image, Offset.zero, paint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image enhancedImage =
        await picture.toImage(image.width, image.height);
    final byteData =
        await enhancedImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final safeMode = mode.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final enhancedFile = File(
      p.join(
        tempDir.path,
        '${safeMode}_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await enhancedFile.writeAsBytes(byteData!.buffer.asUint8List());

    image.dispose();
    enhancedImage.dispose();

    return enhancedFile;
  }

  static ColorFilter _filterForMode(String mode) {
    switch (mode) {
      case 'Sharp B&W':
        return const ColorFilter.matrix(<double>[
          1.95, 1.95, 1.95, 0, -255,
          1.95, 1.95, 1.95, 0, -255,
          1.95, 1.95, 1.95, 0, -255,
          0, 0, 0, 1, 0,
        ]);
      case 'Clean Gray':
        return const ColorFilter.matrix(<double>[
          0.45, 0.55, 0.10, 0, 12,
          0.45, 0.55, 0.10, 0, 12,
          0.45, 0.55, 0.10, 0, 12,
          0, 0, 0, 1, 0,
        ]);
      case 'Magic Color':
      default:
        return const ColorFilter.matrix(<double>[
          1.35, 0, 0, 0, 15,
          0, 1.35, 0, 0, 15,
          0, 0, 1.35, 0, 15,
          0, 0, 0, 1, 0,
        ]);
    }
  }
}
