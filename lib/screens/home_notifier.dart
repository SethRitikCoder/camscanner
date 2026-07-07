import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/document_model.dart';
import '../models/folder_model.dart';
import '../models/local_file_item.dart';
import '../services/database_helper.dart';
import '../services/storage_service.dart';
import '../services/compression_service.dart';
import '../services/ocr_service.dart';

class HomeNotifier extends ChangeNotifier {
  List<FolderModel> folders = [];
  List<LocalFileItem> localFiles = [];
  int? selectedFolderId;
  String searchQuery = "";
  bool isLoading = false;

  HomeNotifier() {
    loadData();
  }

  void setSelectedFolderId(int? folderId) {
    if (selectedFolderId == folderId) return;
    selectedFolderId = folderId;
    notifyListeners();
    loadData();
  }

  void setSearchQuery(String query) {
    if (searchQuery == query) return;
    searchQuery = query;
    notifyListeners();
    loadData();
  }

  String? getActiveFolderName() {
    if (selectedFolderId != null && folders.isNotEmpty) {
      final idx = folders.indexWhere((f) => f.id == selectedFolderId);
      if (idx != -1) return folders[idx].name;
    }
    return null;
  }

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    folders = await DatabaseHelper.instance.getAllFolders();
    await _loadLocalFiles();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadLocalFiles() async {
    try {
      final List<LocalFileItem> items = [];
      
      // If search query is active, use database search
      if (searchQuery.trim().isNotEmpty) {
        final documents = await DatabaseHelper.instance.searchDocuments(
          query: searchQuery,
          folderId: selectedFolderId,
          limit: 50,
        );
        
        for (var doc in documents) {
          try {
            if (doc.pagePaths.isNotEmpty) {
              final firstPagePath = doc.pagePaths[0];
              final file = File(firstPagePath);
              
              if (await file.exists()) {
                final length = await file.length();
                final modifiedTime = await file.lastModified();
                final isPdf = firstPagePath.toLowerCase().endsWith('.pdf');
                final fileSizeText = CompressionService.formatBytes(length);
                final formattedDate =
                    "${modifiedTime.year}-${modifiedTime.month.toString().padLeft(2, '0')}-${modifiedTime.day.toString().padLeft(2, '0')} ${modifiedTime.hour.toString().padLeft(2, '0')}:${modifiedTime.minute.toString().padLeft(2, '0')}";

                final snippet = _extractSnippet(doc.extractedText, searchQuery);

                items.add(LocalFileItem(
                  file: file,
                  name: doc.title,
                  displayTitle: doc.title,
                  fileSizeText: fileSizeText,
                  modifiedTime: modifiedTime,
                  formattedDate: formattedDate,
                  isPdf: isPdf,
                  highlightQuery: searchQuery,
                  extractedTextSnippet: snippet,
                ));
              }
            }
          } catch (e) {
            debugPrint("Failed to load document ${doc.title}: $e");
          }
        }
      } else {
        // No search query, use file system scan
        final activeFolderName = getActiveFolderName();

        final dir =
            await StorageService.getPublicDirectory(folderName: activeFolderName);
        List<File> filesList = [];

        if (selectedFolderId == null) {
          final rootDir = await StorageService.getPublicDirectory();
          if (await rootDir.exists()) {
            await for (final entity
                in rootDir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final path = entity.path.toLowerCase();
                if (path.endsWith('.pdf') ||
                    path.endsWith('.jpg') ||
                    path.endsWith('.jpeg') ||
                    path.endsWith('.png')) {
                  filesList.add(entity);
                }
              }
            }
          }
        } else {
          if (await dir.exists()) {
            await for (final entity
                in dir.list(recursive: false, followLinks: false)) {
              if (entity is File) {
                final path = entity.path.toLowerCase();
                if (path.endsWith('.pdf') ||
                    path.endsWith('.jpg') ||
                    path.endsWith('.jpeg') ||
                    path.endsWith('.png')) {
                  filesList.add(entity);
                }
              }
            }
          }
        }

        for (var file in filesList) {
          try {
            final length = await file.length();
            final modifiedTime = await file.lastModified();
            final fileName = p.basename(file.path);
            final isPdf = fileName.toLowerCase().endsWith('.pdf');
            final displayTitle = _cleanDisplayTitle(fileName);
            final fileSizeText = CompressionService.formatBytes(length);
            final formattedDate =
                "${modifiedTime.year}-${modifiedTime.month.toString().padLeft(2, '0')}-${modifiedTime.day.toString().padLeft(2, '0')} ${modifiedTime.hour.toString().padLeft(2, '0')}:${modifiedTime.minute.toString().padLeft(2, '0')}";

            items.add(LocalFileItem(
              file: file,
              name: fileName,
              displayTitle: displayTitle,
              fileSizeText: fileSizeText,
              modifiedTime: modifiedTime,
              formattedDate: formattedDate,
              isPdf: isPdf,
            ));
          } catch (e) {
            debugPrint("Failed to load details for file ${file.path}: $e");
          }
        }
      }

      items.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      localFiles = items;
    } catch (e) {
      debugPrint("Error loading local files: $e");
    }
  }

  String _extractSnippet(String text, String query, {int contextLength = 40}) {
    if (text.isEmpty || query.isEmpty) return '';
    
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);
    
    if (index == -1) return '';
    
    final start = (index - contextLength).clamp(0, text.length);
    final end = (index + query.length + contextLength).clamp(0, text.length);
    
    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';
    
    return snippet.replaceAll('\n', ' ').trim();
  }

  String _cleanDisplayTitle(String fileName) {
    String nameWithoutExt = fileName.replaceAll(
        RegExp(r'\.(pdf|jpg|jpeg|png)$', caseSensitive: false), '');

    final match = RegExp(r'(\d{10,13})').firstMatch(nameWithoutExt);
    if (match != null) {
      final timestampStr = match.group(1)!;
      final timestamp = int.tryParse(timestampStr);
      if (timestamp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final formattedDate = DateFormat('MM-dd-yyyy HH:mm').format(date);
        return "DocScanner $formattedDate";
      }
    }

    String title = nameWithoutExt.replaceAll(RegExp(r'_page_\d+'), '');
    title = title.replaceAll(RegExp(r'_\d{10,}$'), '');
    title = title.replaceAll('_', ' ');
    return title.trim();
  }

  Future<int> addDocument({
    required List<String> pagePaths,
    required String title,
  }) async {
    final newDoc = DocumentModel(
      folderId: selectedFolderId,
      title: title,
      pagePaths: pagePaths,
      thumbnailPath: pagePaths.first,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final docId = await DatabaseHelper.instance.insertDocument(newDoc);
    await loadData();

    // Start OCR extraction asynchronously
    OcrService.extractTextFromImages(pagePaths).then((extractedText) async {
      if (extractedText.isNotEmpty) {
        final updatedDoc = newDoc.copyWith(id: docId, extractedText: extractedText);
        await DatabaseHelper.instance.updateDocument(updatedDoc);
        await loadData();
      }
    });

    return docId;
  }

  Future<void> createFolder(String name) async {
    await DatabaseHelper.instance.insertFolder(
      FolderModel(
        name: name,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await loadData();
  }

  Future<bool> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await loadData();
      return true;
    } catch (e) {
      debugPrint("Error deleting file: $e");
      return false;
    }
  }

  Future<bool> renameFile(File file, String newName) async {
    try {
      if (!await file.exists()) return false;

      final extension = p.extension(file.path);
      final parentDir = file.parent.path;
      final sanitizedNewName = newName.trim().replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final newPath = p.join(parentDir, '$sanitizedNewName$extension');

      final newFile = await file.rename(newPath);
      await DatabaseHelper.instance.updateDocumentPaths(file.path, newFile.path, sanitizedNewName);
      await loadData();
      return true;
    } catch (e) {
      debugPrint("Error renaming file: $e");
      return false;
    }
  }
}
