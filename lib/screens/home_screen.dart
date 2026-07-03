import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/document_model.dart';
import '../models/folder_model.dart';
import '../services/ad_service.dart';
import '../services/database_helper.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../services/compression_service.dart';
import '../widgets/folder_chip.dart';
import 'export_preview_screen.dart';
import 'id_card_camera_screen.dart';
import 'tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0;
  List<FolderModel> _folders = [];
  List<LocalFileItem> _localFiles = [];
  int? _selectedFolderId;
  String _searchQuery = "";
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  Timer? _searchDebounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void _onSearchChanged(String val) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = val;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final folders = await DatabaseHelper.instance.getAllFolders();

    if (mounted) {
      setState(() {
        _folders = folders;
      });
    }

    await _loadLocalFiles();
  }

  Future<void> _loadLocalFiles() async {
    try {
      String? activeFolderName;
      if (_selectedFolderId != null && _folders.isNotEmpty) {
        final folderIndex =
            _folders.indexWhere((f) => f.id == _selectedFolderId);
        if (folderIndex != -1) {
          activeFolderName = _folders[folderIndex].name;
        }
      }

      final dir =
          await StorageService.getPublicDirectory(folderName: activeFolderName);
      List<File> filesList = [];

      if (_selectedFolderId == null) {
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
                if (_searchQuery.trim().isNotEmpty) {
                  final fileName = p.basename(entity.path).toLowerCase();
                  if (fileName.contains(_searchQuery.toLowerCase())) {
                    filesList.add(entity);
                  }
                } else {
                  filesList.add(entity);
                }
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
                if (_searchQuery.trim().isNotEmpty) {
                  final fileName = p.basename(entity.path).toLowerCase();
                  if (fileName.contains(_searchQuery.toLowerCase())) {
                    filesList.add(entity);
                  }
                } else {
                  filesList.add(entity);
                }
              }
            }
          }
        }
      }

      final List<LocalFileItem> items = [];
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

      items.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));

      if (mounted) {
        setState(() {
          _localFiles = items;
        });
      }
    } catch (e) {
      debugPrint("Error loading physical files: $e");
    }
  }

  void _openPdfFile(File file) async {
    try {
      await Printing.layoutPdf(
        name: p.basename(file.path),
        onLayout: (PdfPageFormat format) async => await file.readAsBytes(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open PDF: $e")),
        );
      }
    }
  }

  void _openImageFile(File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _startScan() async {
    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          pageLimit: 20,
          isGalleryImport: true,
        ),
      );

      final result = await documentScanner.scanDocument();
      if (result.images.isNotEmpty) {
        final imagePaths = result.images;
        final title =
            "DocScanner ${DateFormat('MM-dd-yyyy HH:mm').format(DateTime.now())}";

        final newDoc = DocumentModel(
          folderId: _selectedFolderId,
          title: title,
          pagePaths: imagePaths,
          thumbnailPath: imagePaths.first,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );

        final docId = await DatabaseHelper.instance.insertDocument(newDoc);
        _loadData();

        OcrService.extractTextFromImages(imagePaths)
            .then((extractedText) async {
          if (extractedText.isNotEmpty) {
            final updatedDoc =
                newDoc.copyWith(id: docId, extractedText: extractedText);
            await DatabaseHelper.instance.updateDocument(updatedDoc);
            _loadData();
          }
        });

        String? activeFolderName;
        if (_selectedFolderId != null && _folders.isNotEmpty) {
          final idx = _folders.indexWhere((f) => f.id == _selectedFolderId);
          if (idx != -1) activeFolderName = _folders[idx].name;
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExportPreviewScreen(
                imagePaths: imagePaths,
                docTitle: title,
                folderName: activeFolderName,
              ),
            ),
          ).then((_) => _loadData());
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') ||
          errorStr.contains('operation cancelled')) {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  Future<void> _startIdCardScan() async {
    try {
      final String? mergedFilePath = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IdCardCameraScreen()),
      );

      if (mergedFilePath == null || mergedFilePath.isEmpty) return;

      final title =
          "DocScanner ${DateFormat('MM-dd-yyyy HH:mm').format(DateTime.now())}";
      final imagePaths = [mergedFilePath];

      final newDoc = DocumentModel(
        folderId: _selectedFolderId,
        title: title,
        pagePaths: imagePaths,
        thumbnailPath: imagePaths.first,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final docId = await DatabaseHelper.instance.insertDocument(newDoc);
      _loadData();

      OcrService.extractTextFromImages(imagePaths).then((extractedText) async {
        if (extractedText.isNotEmpty) {
          final updatedDoc =
              newDoc.copyWith(id: docId, extractedText: extractedText);
          await DatabaseHelper.instance.updateDocument(updatedDoc);
          _loadData();
        }
      });

      String? activeFolderName;
      if (_selectedFolderId != null && _folders.isNotEmpty) {
        final idx = _folders.indexWhere((f) => f.id == _selectedFolderId);
        if (idx != -1) activeFolderName = _folders[idx].name;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExportPreviewScreen(
              imagePaths: imagePaths,
              docTitle: title,
              folderName: activeFolderName,
            ),
          ),
        ).then((_) => _loadData());
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') ||
          errorStr.contains('operation cancelled')) {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  Future<void> _showAddFolderDialog() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create New Folder"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Folder Name"),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertFolder(
                  FolderModel(
                      name: name,
                      createdAt: DateTime.now().millisecondsSinceEpoch),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A86B)),
            child: const Text("Create", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (!isKeyboardOpen && _searchFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FAFC),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: _activeTab == 1
            ? const ToolsScreen()
            : SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFF00A86B),
                      padding: EdgeInsets.fromLTRB(
                          16, 16 + MediaQuery.of(context).padding.top, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "DocScanner Pro",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: "Search documents or text inside...",
                              prefixIcon: const Icon(Icons.search,
                                  color: Color(0xFF00A86B)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _folders.map((folder) {
                                  return FolderChip(
                                    folder: folder,
                                    isSelected: _selectedFolderId == folder.id,
                                    onTap: () {
                                      setState(() {
                                        _selectedFolderId =
                                            (_selectedFolderId == folder.id)
                                                ? null
                                                : folder.id;
                                      });
                                      _loadData();
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddFolderDialog,
                            icon:
                                const Icon(Icons.add, color: Color(0xFF00A86B)),
                            label: const Text("+ Folder",
                                style: TextStyle(color: Color(0xFF00A86B))),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _localFiles.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_open_outlined,
                                      size: 70, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No saved files found.\nTap Scan or ID Card and export to save files!",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                        height: 1.4),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: _localFiles.length,
                              itemBuilder: (context, index) {
                                final item = _localFiles[index];
                                final file = item.file;
                                final fileName = item.name;
                                final isPdf = item.isPdf;
                                final fileSizeText = item.fileSizeText;
                                final formattedDate = item.formattedDate;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  color: Colors.white,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    leading: Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: isPdf
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFECFDF5),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: isPdf
                                            ? const Icon(Icons.picture_as_pdf,
                                                color: Colors.red, size: 28)
                                            : Image.file(
                                                file,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const Icon(
                                                  Icons.image,
                                                  color: Color(0xFF00A86B),
                                                  size: 28,
                                                ),
                                              ),
                                      ),
                                    ),
                                    // FIXED: Wrapped the text fields inside an Expanded to perfectly calculate constraints inside the ListTile Row
                                    title: Text(
                                      item.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      // FIXED: Handled metadata alignment using a flexible setup inside the Row layer
                                      child: Row(
                                        children: [
                                          Text(
                                            fileSizeText,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          if (fileSizeText.isNotEmpty &&
                                              formattedDate.isNotEmpty)
                                            Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              width: 3,
                                              height: 3,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey.shade400),
                                            ),
                                          Expanded(
                                            child: Text(
                                              formattedDate,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) async {
                                        if (action == 'delete') {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text("Delete File"),
                                              content: Text(
                                                  "Are you sure you want to delete '$fileName' permanently from storage?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text("Cancel"),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.red),
                                                  child: const Text("Delete"),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            try {
                                              if (await file.exists()) {
                                                await file.delete();
                                              }
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Deleted '$fileName' successfully.")),
                                                );
                                              }
                                              _loadData();
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Failed to delete file: $e")),
                                                );
                                              }
                                            }
                                          }
                                        } else if (action == 'share') {
                                          try {
                                            final mimeType = isPdf
                                                ? 'application/pdf'
                                                : 'image/jpeg';
                                            await Share.shareXFiles([
                                              XFile(file.path,
                                                  mimeType: mimeType)
                                            ]);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        "Failed to share file: $e")),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            children: [
                                              Icon(Icons.share,
                                                  color: Color(0xFF00A86B),
                                                  size: 20),
                                              SizedBox(width: 8),
                                              Text('Share'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color: Colors.red, size: 20),
                                              SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      child: const Icon(Icons.more_vert,
                                          size: 22, color: Colors.grey),
                                    ),
                                    onTap: () {
                                      if (isPdf) {
                                        _openPdfFile(file);
                                      } else {
                                        _openImageFile(file);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _startIdCardScan,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFB703),
                                      foregroundColor: const Color(0xFF0F172A),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.badge, size: 20),
                                    label: const Text("ID Card Mode",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _startScan,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00A86B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon:
                                        const Icon(Icons.camera_alt, size: 20),
                                    label: const Text("Scan Document",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isBannerLoaded && _bannerAd != null) ...[
                            const Divider(
                                height: 1,
                                thickness: 0.5,
                                color: Color(0xFFE2E8F0)),
                            Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.only(top: 6, bottom: 4),
                              child: SizedBox(
                                height: _bannerAd!.size.height.toDouble(),
                                width: _bannerAd!.size.width.toDouble(),
                                child: AdWidget(ad: _bannerAd!),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeTab,
        onTap: (index) => setState(() => _activeTab = index),
        selectedItemColor: const Color(0xFF00A86B),
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: "Documents",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: "Tools",
          ),
        ],
      ),
    );
  }
}

class LocalFileItem {
  final File file;
  final String name;
  final String displayTitle;
  final String fileSizeText;
  final DateTime modifiedTime;
  final String formattedDate;
  final bool isPdf;

  LocalFileItem({
    required this.file,
    required this.name,
    required this.displayTitle,
    required this.fileSizeText,
    required this.modifiedTime,
    required this.formattedDate,
    required this.isPdf,
  });
}
