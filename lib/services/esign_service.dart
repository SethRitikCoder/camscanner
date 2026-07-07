import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ESignService {
  /// Merges drawn signature box onto a specific position of the document image.
  static Future<File> applySignature(
    File sourceFile,
    List<List<Offset>> strokes,
    Size canvasDisplaySize, {
    required Offset boxPosition,     // Premium: Dragged Position coordinate
    required Size boxSize,           // Premium: Resized Box Dimensions
    required Color inkColor,         // Premium: Blue or Black Ink selection
    required double esignRotation,   // Rotation in radians
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final double imgWidth = image.width.toDouble();
    final double imgHeight = image.height.toDouble();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgWidth, imgHeight));

    // 1. Draw original high-quality document background
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    // 2. Global Scaling factors (Widget size to real Image pixel size)
    final double globalScaleX = imgWidth / canvasDisplaySize.width;
    final double globalScaleY = imgHeight / canvasDisplaySize.height;

    // Signature box position in image pixels
    final double finalBoxX = boxPosition.dx * globalScaleX;
    final double finalBoxY = boxPosition.dy * globalScaleY;
    
    // Resized Box width/height in image pixels
    final double finalBoxWidth = boxSize.width * globalScaleX;
    final double finalBoxHeight = boxSize.height * globalScaleY;

    // Normalized touch canvas base size inside the modal pad (which was 300x150)
    const double basePadWidth = 300.0;
    const double basePadHeight = 150.0;

    // Local scaling factor: Modal pad to responsive resize box mapping
    final double localScaleX = finalBoxWidth / basePadWidth;
    final double localScaleY = finalBoxHeight / basePadHeight;

    // 3. Set Dynamic ink color and scale stroke width safely
    final Paint strokePaint = Paint()
      ..color = inkColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5 * (finalBoxWidth / basePadWidth); // Adaptive line thickness

    // 4. Transform canvas to draw rotated signature centered
    canvas.save();
    final double finalCenterX = finalBoxX + finalBoxWidth / 2;
    final double finalCenterY = finalBoxY + finalBoxHeight / 2;
    canvas.translate(finalCenterX, finalCenterY);
    canvas.rotate(esignRotation);
    canvas.translate(-finalBoxWidth / 2, -finalBoxHeight / 2);

    // 5. Draw strokes in transformed coordinate space
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        final double p1LocalX = stroke[i].dx * localScaleX;
        final double p1LocalY = stroke[i].dy * localScaleY;
        final double p2LocalX = stroke[i + 1].dx * localScaleX;
        final double p2LocalY = stroke[i + 1].dy * localScaleY;

        final p1 = Offset(p1LocalX, p1LocalY);
        final p2 = Offset(p2LocalX, p2LocalY);

        canvas.drawLine(p1, p2, strokePaint);
      }
    }
    canvas.restore();

    // 6. Compile and export high-res output file
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