import 'package:flutter_test/flutter_test.dart';
import 'package:cam_scanner/main.dart';
import 'package:cam_scanner/services/database_helper.dart';
import 'package:cam_scanner/models/folder_model.dart';
import 'package:cam_scanner/models/document_model.dart';
import 'package:sqflite/sqflite.dart';

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
}

void main() {
  setUp(() {
    DatabaseHelper.instance = MockDatabaseHelper();
  });

  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const DocScannerApp());
    expect(find.byType(DocScannerApp), findsOneWidget);
    // Allow the splash screen's 3-second delay timer to finish
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
