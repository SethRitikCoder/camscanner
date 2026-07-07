import 'dart:io';

class LocalFileItem {
  final File file;
  final String name;
  final String displayTitle;
  final String fileSizeText;
  final DateTime modifiedTime;
  final String formattedDate;
  final bool isPdf;
  final String? highlightQuery;
  final String? extractedTextSnippet;

  LocalFileItem({
    required this.file,
    required this.name,
    required this.displayTitle,
    required this.fileSizeText,
    required this.modifiedTime,
    required this.formattedDate,
    required this.isPdf,
    this.highlightQuery,
    this.extractedTextSnippet,
  });
}
