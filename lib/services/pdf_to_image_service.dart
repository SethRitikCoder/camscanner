import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

class PdfToImageService {
  /// Extracts all pages from a local PDF file and returns them as separate PNG image files offline.
  static Future<List<File>> convertPdfToImages(File pdfFile) async {
    final List<File> extractedImages = [];
    final pdfBytes = await pdfFile.readAsBytes();
    final tempDir = await getTemporaryDirectory();

    int pageIndex = 1;
    await for (final page in Printing.raster(pdfBytes, dpi: 150)) {
      final pngBytes = await page.toPng();
      final imageFile = File(p.join(tempDir.path, 'pdf_page_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.png'));
      await imageFile.writeAsBytes(pngBytes);
      extractedImages.add(imageFile);
      pageIndex++;
    }

    return extractedImages;
  }
}
