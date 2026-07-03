import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../services/id_card_service.dart';

class IdCardCameraScreen extends StatefulWidget {
  const IdCardCameraScreen({super.key});

  @override
  State<IdCardCameraScreen> createState() => _IdCardCameraScreenState();
}

class _IdCardCameraScreenState extends State<IdCardCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  int _currentStep = 1; // 1 = Front, 2 = Back
  String? _frontImagePath;
  bool _showSuccessPopup = false;

  // Confirmation state variables
  bool _isConfirming = false;
  String? _currentRawImagePath;
  List<Offset>? _currentCropPoints;
  String? _currentCroppedImagePath;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError("No cameras found on device.");
        return;
      }
      
      // Initialize rear camera
      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showError("Failed to initialize camera: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Ensures image is in portrait, rotates by 90 deg clockwise if landscape
  Future<String> _ensurePortraitRawImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image rawImage = frame.image;

    final double rawWidth = rawImage.width.toDouble();
    final double rawHeight = rawImage.height.toDouble();
    final bool isLandscape = rawWidth > rawHeight;

    if (!isLandscape) {
      rawImage.dispose();
      return imagePath;
    }

    final ui.PictureRecorder rotateRecorder = ui.PictureRecorder();
    final Canvas rotateCanvas = Canvas(rotateRecorder, Rect.fromLTWH(0, 0, rawHeight, rawWidth));
    
    rotateCanvas.translate(rawHeight, 0);
    rotateCanvas.rotate(90 * 3.141592653589793 / 180);
    
    rotateCanvas.drawImage(rawImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    
    final ui.Picture rotatePicture = rotateRecorder.endRecording();
    final ui.Image portraitImage = await rotatePicture.toImage(rawHeight.toInt(), rawWidth.toInt());
    final byteData = await portraitImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = File(imagePath).parent;
    final portraitFile = File(p.join(tempDir.path, 'portrait_${DateTime.now().millisecondsSinceEpoch}.png'));
    await portraitFile.writeAsBytes(byteData!.buffer.asUint8List());

    rawImage.dispose();
    portraitImage.dispose();
    return portraitFile.path;
  }

  // Calculate default 1.58:1 crop points for the given portrait image dimensions
  List<Offset> _calculateDefaultCropPoints(double imgWidth, double imgHeight) {
    double cropWidth = imgWidth * 0.85;
    double cropHeight = cropWidth / 1.58;

    if (cropHeight > imgHeight * 0.9) {
      cropHeight = imgHeight * 0.85;
      cropWidth = cropHeight * 1.58;
    }

    final double left = (imgWidth - cropWidth) / 2;
    final double top = (imgHeight - cropHeight) / 2;

    return [
      Offset(left, top), // Top-Left
      Offset(left + cropWidth, top), // Top-Right
      Offset(left + cropWidth, top + cropHeight), // Bottom-Right
      Offset(left, top + cropHeight), // Bottom-Left
    ];
  }

  // Perspective Homography crop of the raw image using 4 points (in pixel coordinates)
  Future<String> _cropImageWithPoints(String rawImagePath, List<Offset> points) async {
    final bytes = await File(rawImagePath).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image rawImage = frame.image;

    const double targetWidth = 1000.0;
    const double targetHeight = 633.0; // 1000 / 1.58

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, targetWidth, targetHeight));

    // Fill background with white
    canvas.drawRect(const Rect.fromLTWH(0, 0, targetWidth, targetHeight), Paint()..color = Colors.white);

    // Calculate homography matrix mapping dest (0,0)..(W,H) to source points
    final double u0 = points[0].dx;
    final double v0 = points[0].dy;
    final double u1 = points[1].dx;
    final double v1 = points[1].dy;
    final double u2 = points[2].dx;
    final double v2 = points[2].dy;
    final double u3 = points[3].dx;
    final double v3 = points[3].dy;

    const double W = targetWidth;
    const double H = targetHeight;

    final double A = (u1 - u2) * W;
    final double B = (u3 - u2) * H;
    final double C = u0 - u1 + u2 - u3;
    final double D = (v1 - v2) * W;
    final double E = (v3 - v2) * H;
    final double F = v0 - v1 + v2 - v3;

    final double det = A * E - B * D;
    double h20 = 0.0;
    double h21 = 0.0;
    if (det.abs() > 1e-5) {
      h20 = (C * E - B * F) / det;
      h21 = (A * F - C * D) / det;
    }

    final double h00 = (u1 - u0) / W + h20 * u1;
    final double h01 = (u3 - u0) / H + h21 * u3;
    final double h02 = u0;
    final double h10 = (v1 - v0) / W + h20 * v1;
    final double h11 = (v3 - v0) / H + h21 * v3;
    final double h12 = v0;

    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, h00);
    matrix.setEntry(0, 1, h01);
    matrix.setEntry(0, 3, h02);
    matrix.setEntry(1, 0, h10);
    matrix.setEntry(1, 1, h11);
    matrix.setEntry(1, 3, h12);
    matrix.setEntry(3, 0, h20);
    matrix.setEntry(3, 1, h21);
    matrix.setEntry(3, 3, 1.0);

    // Invert to get source to dest transform
    try {
      matrix.invert();
    } catch (e) {
      debugPrint("Matrix inversion failed: $e");
    }

    canvas.save();
    canvas.transform(matrix.storage);
    canvas.drawImage(rawImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image croppedImage = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = File(rawImagePath).parent;
    final croppedFile = File(p.join(tempDir.path, 'cropped_${DateTime.now().millisecondsSinceEpoch}.png'));
    await croppedFile.writeAsBytes(byteData!.buffer.asUint8List());

    rawImage.dispose();
    croppedImage.dispose();

    return croppedFile.path;
  }

  // Orchestrator to process captured or picked photo
  Future<void> _processCapturedPhoto(String path) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final portraitPath = await _ensurePortraitRawImage(path);

      // Load image bounds
      final bytes = await File(portraitPath).readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image rawImage = frame.image;
      final double imgWidth = rawImage.width.toDouble();
      final double imgHeight = rawImage.height.toDouble();
      rawImage.dispose();

      final defaultPoints = _calculateDefaultCropPoints(imgWidth, imgHeight);
      final croppedPath = await _cropImageWithPoints(portraitPath, defaultPoints);

      setState(() {
        _currentRawImagePath = portraitPath;
        _currentCropPoints = defaultPoints;
        _currentCroppedImagePath = croppedPath;
        _isConfirming = true;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError("Failed to process image: $e");
    }
  }

  // Open interactive manual crop adjustments modal
  void _openAdjustEdgesScreen() async {
    if (_currentRawImagePath == null || _currentCropPoints == null) return;

    final result = await Navigator.push<List<Offset>>(
      context,
      MaterialPageRoute(
        builder: (context) => AdjustEdgesScreen(
          imagePath: _currentRawImagePath!,
          initialPoints: _currentCropPoints!,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final newCroppedPath = await _cropImageWithPoints(_currentRawImagePath!, result);
        setState(() {
          _currentCropPoints = result;
          _currentCroppedImagePath = newCroppedPath;
          _isProcessing = false;
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
        });
        _showError("Failed to update crop: $e");
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _isConfirming = false;
      _currentRawImagePath = null;
      _currentCropPoints = null;
      _currentCroppedImagePath = null;
    });
  }

  Future<void> _confirmCroppedPhoto() async {
    if (_currentCroppedImagePath == null) return;

    if (_currentStep == 1) {
      _frontImagePath = _currentCroppedImagePath;
      setState(() {
        _isConfirming = false;
        _currentRawImagePath = null;
        _currentCropPoints = null;
        _currentCroppedImagePath = null;
        _showSuccessPopup = true;
      });

      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        setState(() {
          _showSuccessPopup = false;
          _currentStep = 2;
        });
      }
    } else {
      setState(() {
        _isProcessing = true;
      });

      try {
        if (_frontImagePath == null || _frontImagePath!.isEmpty) {
          throw Exception("Front image path is empty.");
        }
        
        final frontFile = File(_frontImagePath!);
        final backFile = File(_currentCroppedImagePath!);

        if (!await frontFile.exists()) {
          throw Exception("Front side image file not found.");
        }
        if (!await backFile.exists()) {
          throw Exception("Back side image file not found.");
        }
        
        final mergedFile = await IdCardService.mergeIdCardImages(frontFile, backFile);
        
        if (mounted) {
          Navigator.pop(context, mergedFile.path);
        }
      } catch (e) {
        _showError("Failed to merge images: $e");
        setState(() {
          _currentStep = 1;
          _frontImagePath = null;
          _isConfirming = false;
          _currentRawImagePath = null;
          _currentCropPoints = null;
          _currentCroppedImagePath = null;
          _isProcessing = false;
          _showSuccessPopup = false;
        });
      }
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile photo = await _controller!.takePicture();
      await _processCapturedPhoto(photo.path);
    } catch (e) {
      _showError("Failed to capture photo: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        await _processCapturedPhoto(image.path);
      }
    } catch (e) {
      _showError("Failed to import photo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00A86B)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth / 1.58; // Standard card aspect ratio (85.60 x 53.98 mm)

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview (kept alive to avoid black flashes)
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // 2. Confirmation Screen Overlay
          if (_isConfirming && _currentCroppedImagePath != null)
            Positioned.fill(
              child: Container(
                color: Colors.black, // Fully covers camera preview
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top Title
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        child: Text(
                          _currentStep == 1
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
                      
                      // Cropped card preview centered
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
                                  File(_currentCroppedImagePath!),
                                  fit: BoxFit.cover,
                                  key: ValueKey(_currentCroppedImagePath), // Reload instantly on adjust
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Instructions
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

                      // Confirmation bottom Row actions
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _retakePhoto,
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
                                onPressed: _openAdjustEdgesScreen,
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
                                onPressed: _confirmCroppedPhoto,
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(
                                  _currentStep == 1 ? "Next" : "Done",
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

          // 3. Regular Camera Overlay (only visible when NOT confirming)
          if (!_isConfirming) ...[
            // Guideline Overlay
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.65),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(
                      color: Colors.transparent,
                    ),
                    Center(
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bounding Box Border
            Center(
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF00A86B),
                    width: 3.0,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A86B).withValues(alpha: 0.35),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

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
                    colors: _currentStep == 1
                        ? [const Color(0xFFD97706), const Color(0xFFF59E0B)] // Amber gradient
                        : [const Color(0xFF047857), const Color(0xFF10B981)], // Emerald green gradient
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
                      _currentStep == 1 ? Icons.camera_alt : Icons.flip_camera_android,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentStep == 1
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
                            onTap: _pickFromGallery,
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
                      onTap: _captureImage,
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

                    // Equal weight space
                    const Expanded(
                      child: SizedBox(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Processing Loader overlay
          if (_isProcessing)
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
          if (_showSuccessPopup)
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
  }
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
