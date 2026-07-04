import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_scanner/main.dart';
import 'package:cam_scanner/services/database_helper.dart';
import 'package:cam_scanner/models/folder_model.dart';
import 'package:cam_scanner/models/document_model.dart';
import 'package:sqflite/sqflite.dart';

late File testFile;

class MockDatabaseHelper extends DatabaseHelper {
  MockDatabaseHelper() : super.internal();

  @override
  Future<Database> get database => throw UnimplementedError();

  @override
  Future<List<FolderModel>> getAllFolders() async {
    return [];
  }

  @override
  Future<List<DocumentModel>> getDocuments({int? folderId, String? query}) async {
    return [];
  }

  @override
  Future<List<DocumentModel>> searchDocuments({
    required String query,
    int? folderId,
    int limit = 50,
  }) async {
    if (query.toLowerCase() == 'test') {
      return [
        DocumentModel(
          id: 1,
          folderId: folderId,
          title: 'Test Document',
          pagePaths: [testFile.path],
          thumbnailPath: testFile.path,
          extractedText: 'This is some test OCR extracted text.',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
    }
    return [];
  }
}

void main() {
  setUpAll(() {
    final tempDir = Directory.systemTemp.createTempSync();
    testFile = File('${tempDir.path}/test_page.jpg')..createSync();
  });

  setUp(() {
    DatabaseHelper.instance = MockDatabaseHelper();
  });

  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const DocScannerApp());
    expect(find.byType(DocScannerApp), findsOneWidget);
    // Allow the splash screen's 3-second delay timer to finish
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('Search and highlighting test', (WidgetTester tester) async {
    await tester.pumpWidget(const DocScannerApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Find search field and type 'test'
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'test');

    // Wait for the 300ms debounce
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verify clear button is shown in textfield
    expect(find.byIcon(Icons.cancel), findsOneWidget);

    // Verify document loaded and is displayed
    expect(find.textContaining('Test Document'), findsWidgets);
    expect(find.textContaining('test OCR'), findsWidgets);

    // Tap the clear button
    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    // Verify search is cleared
    expect(find.byIcon(Icons.cancel), findsNothing);
  });
}
