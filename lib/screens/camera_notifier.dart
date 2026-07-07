import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../services/id_card_service.dart';

class CameraNotifier extends ChangeNotifier {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool isCameraInitialized = false;
  bool isProcessing = false;
  int currentStep = 1; // 1 = Front, 2 = Back
  String? frontImagePath;
  bool showSuccessPopup = false;

  // Confirmation state variables
  bool isConfirming = false;
  String? currentRawImagePath;
  List<Offset>? currentCropPoints;
  String? currentCroppedImagePath;

  String? errorMessage;

  bool get isFrontCaptured => currentStep == 2;

  CameraNotifier() {
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      var status = await Permission.camera.status;
      if (status.isDenied) {
        status = await Permission.camera.request();
      }

      if (status.isPermanentlyDenied) {
        errorMessage = "permission_permanently_denied";
        isCameraInitialized = true;
        notifyListeners();
        return;
      }

      if (!status.isGranted) {
        errorMessage = "permission_denied";
        isCameraInitialized = true;
        notifyListeners();
        return;
      }

      cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = "No cameras found on device.";
        isCameraInitialized = true;
        notifyListeners();
        return;
      }
      
      controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller!.initialize();
      isCameraInitialized = true;
      errorMessage = null;
      notifyListeners();
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
      isCameraInitialized = true;
      notifyListeners();
    }
  }

  Future<void> requestPermissionAndInit() async {
    errorMessage = null;
    isCameraInitialized = false;
    notifyListeners();
    
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    await initCamera();
  }

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

  Future<String> _cropImageWithPoints(String rawImagePath, List<Offset> points) async {
    final bytes = await File(rawImagePath).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image rawImage = frame.image;

    const double targetWidth = 1000.0;
    const double targetHeight = 633.0; // 1000 / 1.58

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, targetWidth, targetHeight));

    canvas.drawRect(const Rect.fromLTWH(0, 0, targetWidth, targetHeight), Paint()..color = Colors.white);

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

  Future<void> processCapturedPhoto(String path) async {
    isProcessing = true;
    notifyListeners();

    try {
      final portraitPath = await _ensurePortraitRawImage(path);

      final bytes = await File(portraitPath).readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image rawImage = frame.image;
      final double imgWidth = rawImage.width.toDouble();
      final double imgHeight = rawImage.height.toDouble();
      rawImage.dispose();

      final defaultPoints = _calculateDefaultCropPoints(imgWidth, imgHeight);
      final croppedPath = await _cropImageWithPoints(portraitPath, defaultPoints);

      currentRawImagePath = portraitPath;
      currentCropPoints = defaultPoints;
      currentCroppedImagePath = croppedPath;
      isConfirming = true;
    } catch (e) {
      debugPrint("Failed to process image: $e");
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> updateCropPoints(List<Offset> newPoints) async {
    if (currentRawImagePath == null) return;
    isProcessing = true;
    notifyListeners();

    try {
      final newCroppedPath = await _cropImageWithPoints(currentRawImagePath!, newPoints);
      currentCropPoints = newPoints;
      currentCroppedImagePath = newCroppedPath;
    } catch (e) {
      debugPrint("Failed to update crop: $e");
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  void retakePhoto() {
    isConfirming = false;
    currentRawImagePath = null;
    currentCropPoints = null;
    currentCroppedImagePath = null;
    notifyListeners();
  }

  Future<String?> confirmCroppedPhoto() async {
    if (currentCroppedImagePath == null) return null;

    if (currentStep == 1) {
      frontImagePath = currentCroppedImagePath;
      isConfirming = false;
      currentRawImagePath = null;
      currentCropPoints = null;
      currentCroppedImagePath = null;
      showSuccessPopup = true;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 1200));

      showSuccessPopup = false;
      currentStep = 2;
      notifyListeners();
      return null;
    } else {
      isProcessing = true;
      notifyListeners();

      try {
        if (frontImagePath == null || frontImagePath!.isEmpty) {
          throw Exception("Front image path is empty.");
        }
        
        final frontFile = File(frontImagePath!);
        final backFile = File(currentCroppedImagePath!);

        if (!await frontFile.exists()) {
          throw Exception("Front side image file not found.");
        }
        if (!await backFile.exists()) {
          throw Exception("Back side image file not found.");
        }
        
        final mergedFile = await IdCardService.mergeIdCardImages(frontFile, backFile);
        
        resetState();
        return mergedFile.path;
      } catch (e) {
        debugPrint("Failed to merge images: $e");
        resetState();
        return null;
      }
    }
  }

  void resetState() {
    currentStep = 1;
    frontImagePath = null;
    isConfirming = false;
    currentRawImagePath = null;
    currentCropPoints = null;
    currentCroppedImagePath = null;
    isProcessing = false;
    showSuccessPopup = false;
    notifyListeners();
  }

  Future<void> captureImage() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isTakingPicture) return;

    try {
      final XFile photo = await controller!.takePicture();
      await processCapturedPhoto(photo.path);
    } catch (e) {
      debugPrint("Failed to capture photo: $e");
    }
  }

  Future<void> pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        await processCapturedPhoto(image.path);
      }
    } catch (e) {
      debugPrint("Failed to import photo: $e");
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
