import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<String> extractTextFromImages(List<String> imagePaths) async {
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < imagePaths.length; i++) {
      try {
        final inputImage = InputImage.fromFilePath(imagePaths[i]);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

        if (recognizedText.text.trim().isNotEmpty) {
          buffer.writeln('--- Page ${i + 1} ---');
          buffer.writeln(recognizedText.text.trim());
          buffer.writeln();
        }
      } catch (e) {
        // Handle gracefully if an image fails parsing
      }
    }

    return buffer.toString().trim();
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
