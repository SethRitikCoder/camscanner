import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class IdCardService {
  /// Programmatically merges front and back ID card images onto an A4 canvas vertically.
  static Future<File> mergeIdCardImages(File frontFile, File backFile) async {
    if (!await frontFile.exists()) {
      throw Exception("Front image file does not exist.");
    }
    if (!await backFile.exists()) {
      throw Exception("Back image file does not exist.");
    }

    final frontBytes = await frontFile.readAsBytes();
    final backBytes = await backFile.readAsBytes();

    // Optimize decoding by specifying targetWidth to avoid Out Of Memory (OOM) on large camera images
    final ui.Codec frontCodec = await ui.instantiateImageCodec(frontBytes, targetWidth: 1000);
    final ui.FrameInfo frontFrame = await frontCodec.getNextFrame();
    final ui.Image frontImage = frontFrame.image;

    final ui.Codec backCodec = await ui.instantiateImageCodec(backBytes, targetWidth: 1000);
    final ui.FrameInfo backFrame = await backCodec.getNextFrame();
    final ui.Image backImage = backFrame.image;

    // Standard A4 dimensions at ~150 DPI (1240 x 1754)
    const double canvasWidth = 1240.0;
    const double canvasHeight = 1754.0;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

    // Fill background with clean white
    final Paint bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), bgPaint);

    // Border paint for clean ID card cards
    final Paint borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Target constraints for each card to fit vertically on standard A4 (1240 x 1754)
    const double targetWidth = 1000.0;
    const double targetHeight = 633.0; // 1000 / 1.58 (aspect ratio of standard ID Card)

    // Calculate Front image size and layout
    final double frontRatio = frontImage.width / frontImage.height;
    double frontWidth = targetWidth;
    double frontHeight = targetWidth / frontRatio;
    if (frontHeight > targetHeight) {
      frontHeight = targetHeight;
      frontWidth = targetHeight * frontRatio;
    }
    final double frontLeft = (canvasWidth - frontWidth) / 2;
    final double frontTop = 150.0 + (targetHeight - frontHeight) / 2; // Center vertically within the upper slot

    final Rect frontDst = Rect.fromLTWH(frontLeft, frontTop, frontWidth, frontHeight);
    canvas.drawImageRect(
      frontImage,
      Rect.fromLTWH(0, 0, frontImage.width.toDouble(), frontImage.height.toDouble()),
      frontDst,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.drawRect(frontDst, borderPaint);

    // Calculate Back image size and layout
    final double backRatio = backImage.width / backImage.height;
    double backWidth = targetWidth;
    double backHeight = targetWidth / backRatio;
    if (backHeight > targetHeight) {
      backHeight = targetHeight;
      backWidth = targetHeight * backRatio;
    }
    final double backLeft = (canvasWidth - backWidth) / 2;
    final double backTop = 150.0 + targetHeight + 150.0 + (targetHeight - backHeight) / 2; // Center vertically within the lower slot

    final Rect backDst = Rect.fromLTWH(backLeft, backTop, backWidth, backHeight);
    canvas.drawImageRect(
      backImage,
      Rect.fromLTWH(0, 0, backImage.width.toDouble(), backImage.height.toDouble()),
      backDst,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.drawRect(backDst, borderPaint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image mergedImage = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
    final byteData = await mergedImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final tempPngFile = File(p.join(tempDir.path, 'temp_merge_${DateTime.now().millisecondsSinceEpoch}.png'));
    await tempPngFile.writeAsBytes(byteData!.buffer.asUint8List());

    final targetJpgPath = p.join(tempDir.path, 'id_card_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      tempPngFile.absolute.path,
      targetJpgPath,
      quality: 95,
      format: CompressFormat.jpeg,
    );

    // Clean up temp PNG file
    try {
      await tempPngFile.delete();
    } catch (_) {}

    // Dispose native handles immediately to prevent memory leaks / OOM
    frontImage.dispose();
    backImage.dispose();
    mergedImage.dispose();

    if (compressedFile != null) {
      return File(compressedFile.path);
    } else {
      return File(targetJpgPath)..writeAsBytes(byteData.buffer.asUint8List());
    }
  }
}
