import 'dart:convert';

class DocumentModel {
  final int? id;
  final int? folderId;
  final String title;
  final List<String> pagePaths;
  final String thumbnailPath;
  final String extractedText;
  final int createdAt;

  DocumentModel({
    this.id,
    this.folderId,
    required this.title,
    required this.pagePaths,
    required this.thumbnailPath,
    this.extractedText = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folderId': folderId,
      'title': title,
      'pagePaths': jsonEncode(pagePaths),
      'thumbnailPath': thumbnailPath,
      'extractedText': extractedText,
      'createdAt': createdAt,
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    List<String> pages = [];
    if (map['pagePaths'] != null) {
      final decoded = jsonDecode(map['pagePaths'] as String);
      if (decoded is List) {
        pages = decoded.map((e) => e.toString()).toList();
      }
    }

    return DocumentModel(
      id: map['id'] as int?,
      folderId: map['folderId'] as int?,
      title: map['title'] as String,
      pagePaths: pages,
      thumbnailPath: map['thumbnailPath'] as String? ?? '',
      extractedText: map['extractedText'] as String? ?? '',
      createdAt: map['createdAt'] as int,
    );
  }

  DocumentModel copyWith({
    int? id,
    int? folderId,
    String? title,
    List<String>? pagePaths,
    String? thumbnailPath,
    String? extractedText,
    int? createdAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      pagePaths: pagePaths ?? this.pagePaths,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      extractedText: extractedText ?? this.extractedText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
