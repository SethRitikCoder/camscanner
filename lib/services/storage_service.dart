import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  /// Returns the public "MyScannerApp" directory or subfolder on Android,
  /// and the application documents subdirectory on iOS.
  static Future<Directory> getPublicDirectory({String? folderName}) async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      // Try using the public Documents folder directly
      baseDir = Directory('/storage/emulated/0/Documents');
      bool canWritePublic = false;
      try {
        if (!await baseDir.exists()) {
          await baseDir.create(recursive: true);
        }
        // Write test to verify access compatibility (Scoped Storage / Write Permission)
        final testFile = File(p.join(baseDir.path, '.write_test'));
        await testFile.writeAsString('test');
        await testFile.delete();
        canWritePublic = true;
      } catch (_) {
        canWritePublic = false;
      }

      if (!canWritePublic) {
        try {
          final extDir = await getExternalStorageDirectory();
          baseDir = extDir ?? await getApplicationDocumentsDirectory();
        } catch (e) {
          debugPrint("Failed to get external storage directory: $e");
          baseDir = await getApplicationDocumentsDirectory();
        }
      }
    } else {
      // iOS fallback
      baseDir = await getApplicationDocumentsDirectory();
    }

    // Main public scanner app folder
    String targetPath = p.join(baseDir.path, 'DocScannerPro');

    // Optionally organize files into subfolders corresponding to user folders
    if (folderName != null && folderName.trim().isNotEmpty) {
      // Sanitize folder name for paths
      final sanitizedFolder = folderName.trim().replaceAll(RegExp(r'[^\w\.-]'), '_');
      targetPath = p.join(targetPath, sanitizedFolder);
    }

    final customDir = Directory(targetPath);
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }
    return customDir;
  }
}
