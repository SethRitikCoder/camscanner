import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'camera_notifier.dart';

class IdCardCameraScreen extends StatelessWidget {
  const IdCardCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CameraNotifier>(
      create: (_) => CameraNotifier(),
      child: const _IdCardCameraScreenContent(),
    );
  }
}

class _IdCardCameraScreenContent extends StatelessWidget {
  const _IdCardCameraScreenContent();

  void _openAdjustEdgesScreen(BuildContext context, CameraNotifier notifier) async {
    if (notifier.currentRawImagePath == null || notifier.currentCropPoints == null) return;

    final result = await Navigator.push<List<Offset>>(
      context,
      MaterialPageRoute(
        builder: (context) => AdjustEdgesScreen(
          imagePath: notifier.currentRawImagePath!,
          initialPoints: notifier.currentCropPoints!,
        ),
      ),
    );

    if (result != null && context.mounted) {
      notifier.updateCropPoints(result);
    }
  }

  Future<void> _confirmCroppedPhoto(BuildContext context, CameraNotifier notifier) async {
    final mergedPath = await notifier.confirmCroppedPhoto();
    if (mergedPath != null && context.mounted) {
      Navigator.pop(context, mergedPath);
    }
  }

  String _getReadableErrorMessage(String? msg) {
    if (msg == "permission_permanently_denied") {
      return "Camera permission is permanently denied.\nWe need camera access to capture ID cards. Please enable it in system settings.";
    }
    if (msg == "permission_denied") {
      return "Camera access permission was denied.\nWe need camera access to capture your ID card. Tap below to grant permission.";
    }
    return msg ?? "Initializing camera...";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraNotifier>(
      builder: (context, notifier, child) {
        if (!notifier.isCameraInitialized && notifier.errorMessage == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00A86B)),
            ),
          );
        }

        final size = MediaQuery.of(context).size;
        final cardWidth = size.width * 0.85;
        final cardHeight = cardWidth / 1.58;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 1. Camera Preview or Error Placeholder
              Positioned.fill(
                child: (notifier.controller != null && notifier.controller!.value.isInitialized)
                    ? AspectRatio(
                        aspectRatio: notifier.controller!.value.aspectRatio,
                        child: CameraPreview(notifier.controller!),
                      )
                    : Container(
                        color: Colors.black87,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 64),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _getReadableErrorMessage(notifier.errorMessage),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
                                ),
                              ),
                              if (notifier.errorMessage != null &&
                                  (notifier.errorMessage!.contains("permission") ||
                                      notifier.errorMessage!.contains("denied"))) ...[
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => notifier.requestPermissionAndInit(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00A86B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  icon: const Icon(Icons.security, size: 18),
                                  label: Text(notifier.errorMessage == "permission_permanently_denied"
                                      ? "Open App Settings"
                                      : "Grant Permission"),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),

              // 2. Confirmation Screen Overlay
              if (notifier.isConfirming && notifier.currentCroppedImagePath != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                            child: Text(
                              notifier.currentStep == 1
                                  ? "📸 CONFIRM FRONT SIDE"
                                  : "🔄 CONFIRM BACK SIDE",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          
                          Expanded(
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFF00A86B).withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AspectRatio(
                                    aspectRatio: 1.58,
                                    child: Image.file(
                                      File(notifier.currentCroppedImagePath!),
                                      fit: BoxFit.cover,
                                      key: ValueKey(notifier.currentCroppedImagePath),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Text(
                              "Verify the cropped region. Tap 'Adjust Edges' to tweak the crop nodes manually.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => notifier.retakePhoto(),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text("Retake", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openAdjustEdgesScreen(context, notifier),
                                    icon: const Icon(Icons.crop_free, size: 18),
                                    label: const Text("Adjust Edges", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E293B),
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFF00A86B), width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _confirmCroppedPhoto(context, notifier),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: Text(
                                      notifier.currentStep == 1 ? "Next" : "Done",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00A86B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Camera Guide Overlay Custom Painter (visible when NOT confirming)
              if (!notifier.isConfirming)
                Positioned.fill(
                  child: CustomPaint(
                    painter: CardOverlayPainter(isFrontCaptured: notifier.isFrontCaptured),
                  ),
                ),

              if (!notifier.isConfirming) ...[
                // Guideline Info Box text
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: cardHeight + 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Fit card inside the green box",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Top Dynamic Guide Banner
                Positioned(
                  top: 24 + MediaQuery.of(context).padding.top,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: notifier.currentStep == 1
                            ? [const Color(0xFFD97706), const Color(0xFFF59E0B)]
                            : [const Color(0xFF047857), const Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          notifier.currentStep == 1 ? Icons.camera_alt : Icons.flip_camera_android,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            notifier.currentStep == 1
                                ? "📸 STEP 1: PLACE ID CARD FRONT SIDE INSIDE THE BOX"
                                : "🔄 STEP 2: NOW TURN OVER & PLACE ID CARD BACK SIDE",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Close Button
                Positioned(
                  top: 30 + MediaQuery.of(context).padding.top,
                  right: 24,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Bottom Action Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    child: Row(
                      children: [
                        // Gallery Button
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => notifier.pickFromGallery(),
                                borderRadius: BorderRadius.circular(30),
                                child: Ink(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white24,
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Shutter Button
                        GestureDetector(
                          onTap: () => notifier.captureImage(),
                          child: Container(
                            height: 76,
                            width: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const Expanded(
                          child: SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Processing Loader overlay
              if (notifier.isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.75),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00A86B)),
                        SizedBox(height: 16),
                        Text(
                          "Processing ID Card...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Success popup
              if (notifier.showSuccessPopup)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.85),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF00A86B), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00A86B),
                              ),
                              child: const Icon(
                                  Icons.check,
                                  size: 48,
                                  color: Colors.white,
                                ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Front Side Captured\nSuccessfully! 👍",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CardOverlayPainter extends CustomPainter {
  final bool isFrontCaptured;
  
  CardOverlayPainter({required this.isFrontCaptured});
  
  @override
  void paint(Canvas canvas, Size size) {
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth / 1.58;
    final left = (size.width - cardWidth) / 2;
    final top = (size.height - cardHeight) / 2;
    
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cardWidth, cardHeight),
      const Radius.circular(16),
    );
    
    // 1. Draw semi-transparent background with hole
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cardRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(backgroundPath, backgroundPaint);
    
    // 2. Draw border shadow (glow effect)
    final glowColor = isFrontCaptured ? const Color(0xFF00A86B) : const Color(0xFFFFB703);
    final shadowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(cardRect, shadowPaint);
    
    // 3. Bounding box border
    final borderPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(cardRect, borderPaint);
  }
  
  @override
  bool shouldRepaint(covariant CardOverlayPainter oldDelegate) =>
      oldDelegate.isFrontCaptured != isFrontCaptured;
}

Size getDisplayImageSize(Size constraintSize, double imgWidth, double imgHeight) {
  double imgRatio = imgWidth / imgHeight;
  double constraintRatio = constraintSize.width / constraintSize.height;

  double displayWidth;
  double displayHeight;
  if (imgRatio > constraintRatio) {
    displayWidth = constraintSize.width;
    displayHeight = constraintSize.width / imgRatio;
  } else {
    displayHeight = constraintSize.height;
    displayWidth = constraintSize.height * imgRatio;
  }
  return Size(displayWidth, displayHeight);
}

class AdjustEdgesScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset> initialPoints;

  const AdjustEdgesScreen({
    super.key,
    required this.imagePath,
    required this.initialPoints,
  });

  @override
  State<AdjustEdgesScreen> createState() => _AdjustEdgesScreenState();
}

class _AdjustEdgesScreenState extends State<AdjustEdgesScreen> {
  late List<Offset> _points;
  bool _isImageLoaded = false;
  double _imgWidth = 0;
  double _imgHeight = 0;
  int _activeCornerIndex = -1;

  @override
  void initState() {
    super.initState();
    _points = List.from(widget.initialPoints);
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    if (mounted) {
      setState(() {
        _imgWidth = image.width.toDouble();
        _imgHeight = image.height.toDouble();
        _isImageLoaded = true;
      });
    }
    image.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImageLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00A86B)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Adjust Edges"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _points);
            },
            child: const Text(
              "Done",
              style: TextStyle(
                color: Color(0xFF00A86B),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
                final displaySize = getDisplayImageSize(containerSize, _imgWidth, _imgHeight);

                return Center(
                  child: Container(
                    width: displaySize.width,
                    height: displaySize.height,
                    color: Colors.grey[900],
                    child: InteractiveViewer(
                      maxScale: 4.0,
                      minScale: 1.0,
                      scaleEnabled: _activeCornerIndex == -1,
                      panEnabled: _activeCornerIndex == -1,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              onPanStart: (details) {
                                final localPos = details.localPosition;
                                int closestIdx = -1;
                                double minDistance = double.infinity;
                                for (int i = 0; i < _points.length; i++) {
                                  final pDisplay = Offset(
                                    _points[i].dx / _imgWidth * displaySize.width,
                                    _points[i].dy / _imgHeight * displaySize.height,
                                  );
                                  final dist = (localPos - pDisplay).distance;
                                  if (dist < minDistance) {
                                    minDistance = dist;
                                    closestIdx = i;
                                  }
                                }

                                if (closestIdx != -1 && minDistance < 40.0) {
                                  setState(() {
                                    _activeCornerIndex = closestIdx;
                                  });
                                }
                              },
                              onPanUpdate: (details) {
                                if (_activeCornerIndex != -1) {
                                  final localPos = details.localPosition;
                                  final clampedX = localPos.dx.clamp(0.0, displaySize.width);
                                  final clampedY = localPos.dy.clamp(0.0, displaySize.height);

                                  final rawX = (clampedX / displaySize.width) * _imgWidth;
                                  final rawY = (clampedY / displaySize.height) * _imgHeight;

                                  setState(() {
                                    _points[_activeCornerIndex] = Offset(rawX, rawY);
                                  });
                                }
                              },
                              onPanEnd: (_) {
                                setState(() {
                                  _activeCornerIndex = -1;
                                });
                              },
                              onPanCancel: () {
                                setState(() {
                                  _activeCornerIndex = -1;
                                });
                              },
                              child: CustomPaint(
                                painter: CropOverlayPainter(
                                  points: _points,
                                  imgWidth: _imgWidth,
                                  imgHeight: _imgHeight,
                                  displaySize: displaySize,
                                ),
                                child: Container(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            color: Colors.black,
            child: const Center(
              child: Text(
                "Drag the corners to match the card's boundary.\nUse pinch to zoom for precision.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final List<Offset> points;
  final double imgWidth;
  final double imgHeight;
  final Size displaySize;

  CropOverlayPainter({
    required this.points,
    required this.imgWidth,
    required this.imgHeight,
    required this.displaySize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;

    final p0 = Offset(points[0].dx / imgWidth * displaySize.width, points[0].dy / imgHeight * displaySize.height);
    final p1 = Offset(points[1].dx / imgWidth * displaySize.width, points[1].dy / imgHeight * displaySize.height);
    final p2 = Offset(points[2].dx / imgWidth * displaySize.width, points[2].dy / imgHeight * displaySize.height);
    final p3 = Offset(points[3].dx / imgWidth * displaySize.width, points[3].dy / imgHeight * displaySize.height);

    // 1. Draw overlay with hole
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, displaySize.width, displaySize.height))
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    overlayPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withValues(alpha: 0.6));

    // 2. Draw connecting lines
    final linePaint = Paint()
      ..color = const Color(0xFF00A86B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawLine(p0, p1, linePaint);
    canvas.drawLine(p1, p2, linePaint);
    canvas.drawLine(p2, p3, linePaint);
    canvas.drawLine(p3, p0, linePaint);

    // 3. Draw draggable corner handles
    final handleOuterPaint = Paint()..color = const Color(0xFF00A86B);
    final handleInnerPaint = Paint()..color = Colors.white;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final p in [p0, p1, p2, p3]) {
      canvas.drawCircle(p + const Offset(0, 2), 12.0, shadowPaint);
      canvas.drawCircle(p, 12.0, handleOuterPaint);
      canvas.drawCircle(p, 5.0, handleInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.imgWidth != imgWidth ||
        oldDelegate.imgHeight != imgHeight ||
        oldDelegate.displaySize != displaySize;
  }
}
