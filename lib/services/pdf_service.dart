import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart';
import 'storage_service.dart';

class PdfService {
  static Future<File> generatePdf(List<File> imageFiles, String docTitle, {String? folderName}) async {
    final pdf = pw.Document();

    for (File imageFile in imageFiles) {
      if (await imageFile.exists()) {
        try {
          final imageBytes = await imageFile.readAsBytes();
          final pdfImage = pw.MemoryImage(imageBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        } catch (e) {
          // Skip unparseable image bytes gracefully
        }
      }
    }

    final safeTitle = docTitle.replaceAll(':', '-').replaceAll(RegExp(r'[\\*?"<>|]'), '_');
    final outputDir = await StorageService.getPublicDirectory(folderName: folderName);
    
    var pdfFile = File(join(outputDir.path, '$safeTitle.pdf'));
    int counter = 1;
    while (await pdfFile.exists()) {
      pdfFile = File(join(outputDir.path, '${safeTitle}_$counter.pdf'));
      counter++;
    }
    
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile;
  }
}
