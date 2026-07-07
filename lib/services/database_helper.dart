import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document_model.dart';
import '../models/folder_model.dart';

class DatabaseHelper {
  static DatabaseHelper instance = DatabaseHelper.internal();
  static Database? _database;

  DatabaseHelper.internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('doc_scanner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        colorHex TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folderId INTEGER,
        title TEXT NOT NULL,
        pagePaths TEXT NOT NULL,
        thumbnailPath TEXT NOT NULL,
        extractedText TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for fast searching
    await _ensureIndexes(db);

    // Seed default folders as requested (Personal, Work, Receipts)
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('folders', {'name': 'Personal', 'colorHex': '#00A86B', 'createdAt': now});
    await db.insert('folders', {'name': 'Work', 'colorHex': '#0F172A', 'createdAt': now});
    await db.insert('folders', {'name': 'Receipts', 'colorHex': '#FFB703', 'createdAt': now});
  }


  Future<void> _ensureIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_documents_title ON documents(title)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_documents_extracted_text ON documents(extractedText)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(createdAt)',
    );
  }
  // Folders CRUD
  Future<int> insertFolder(FolderModel folder) async {
    final db = await instance.database;
    return await db.insert('folders', folder.toMap());
  }

  Future<List<FolderModel>> getAllFolders() async {
    final db = await instance.database;
    final result = await db.query('folders', orderBy: 'name ASC');
    return result.map((json) => FolderModel.fromMap(json)).toList();
  }

  // Documents CRUD & Smart Search
  Future<int> insertDocument(DocumentModel doc) async {
    final db = await instance.database;
    return await db.insert('documents', doc.toMap());
  }

  Future<int> updateDocument(DocumentModel doc) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<List<DocumentModel>> getDocuments({int? folderId, String? query}) async {
    final db = await instance.database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (query != null && query.trim().isNotEmpty) {
      whereClause = '(title LIKE ? OR extractedText LIKE ?)';
      final q = '%${query.trim()}%';
      whereArgs = [q, q];
      if (folderId != null) {
        whereClause += ' AND folderId = ?';
        whereArgs.add(folderId);
      }
    } else if (folderId != null) {
      whereClause = 'folderId = ?';
      whereArgs = [folderId];
    }

    final result = await db.query(
      'documents',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => DocumentModel.fromMap(json)).toList();
  }


  Future<List<DocumentModel>> searchDocuments({
    required String query,
    int? folderId,
    int limit = 50,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final db = await instance.database;
    final likeQuery = '%$cleanQuery%';
    final whereParts = <String>['(title LIKE ? OR extractedText LIKE ?)'];
    final whereArgs = <Object?>[likeQuery, likeQuery];

    if (folderId != null) {
      whereParts.add('folderId = ?');
      whereArgs.add(folderId);
    }

    final result = await db.query(
      'documents',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
      limit: limit,
    );

    return result.map((json) => DocumentModel.fromMap(json)).toList();
  }
  Future<void> updateDocumentPaths(String oldPath, String newPath, String newTitle) async {
    final db = await instance.database;
    
    final docs = await db.query(
      'documents',
      where: 'pagePaths LIKE ? OR thumbnailPath = ?',
      whereArgs: ['%$oldPath%', oldPath],
    );

    for (var docMap in docs) {
      final doc = DocumentModel.fromMap(docMap);
      final newPages = doc.pagePaths.map((p) => p == oldPath ? newPath : p).toList();
      final newThumb = doc.thumbnailPath == oldPath ? newPath : doc.thumbnailPath;
      
      final updated = doc.copyWith(
        title: newTitle,
        pagePaths: newPages,
        thumbnailPath: newThumb,
      );
      
      await updateDocument(updated);
    }
  }

  Future<int> deleteDocument(int id) async {
    final db = await instance.database;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
