import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../services/ad_service.dart';
import '../widgets/folder_chip.dart';
import 'export_preview_screen.dart';
import 'id_card_camera_screen.dart';
import 'tools_screen.dart';
import 'home_notifier.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  Timer? _searchDebounce;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  void _onSearchChanged(BuildContext context, String val) {
    setState(() {}); // Rebuild to show/hide cancel/clear button immediately
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        context.read<HomeNotifier>().setSearchQuery(val);
      }
    });
  }

  void _clearSearch(BuildContext context) {
    _searchController.clear();
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    setState(() {}); // Rebuild to hide cancel/clear button immediately
    context.read<HomeNotifier>().setSearchQuery("");
  }

  Widget _highlightedText(
    String text,
    String? query, {
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (query == null || query.trim().isEmpty) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final cleanQuery = query.trim();
    final lowerText = text.toLowerCase();
    final lowerQuery = cleanQuery.toLowerCase();

    final List<TextSpan> spans = [];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + cleanQuery.length),
        style: highlightStyle,
      ));

      start = index + cleanQuery.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
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

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFF00A86B)),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startScan(BuildContext context, HomeNotifier notifier) async {
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

        if (context.mounted) {
          _showLoadingDialog(context, "Saving document...");
        }

        await notifier.addDocument(
          pagePaths: imagePaths,
          title: title,
        );

        final activeFolderName = notifier.getActiveFolderName();

        if (context.mounted) {
          Navigator.pop(context); // Pop loading dialog
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExportPreviewScreen(
                imagePaths: imagePaths,
                docTitle: title,
                folderName: activeFolderName,
              ),
            ),
          );
          notifier.loadData();
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') ||
          errorStr.contains('operation cancelled')) {
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  Future<void> _startIdCardScan(BuildContext context, HomeNotifier notifier) async {
    try {
      final String? mergedFilePath = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IdCardCameraScreen()),
      );

      if (mergedFilePath == null || mergedFilePath.isEmpty) return;

      final title =
          "DocScanner ${DateFormat('MM-dd-yyyy HH:mm').format(DateTime.now())}";
      final imagePaths = [mergedFilePath];

      if (context.mounted) {
        _showLoadingDialog(context, "Saving document...");
      }

      await notifier.addDocument(
        pagePaths: imagePaths,
        title: title,
      );

      final activeFolderName = notifier.getActiveFolderName();

      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExportPreviewScreen(
              imagePaths: imagePaths,
              docTitle: title,
              folderName: activeFolderName,
            ),
          ),
        );
        notifier.loadData();
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') ||
          errorStr.contains('operation cancelled')) {
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  Future<void> _showAddFolderDialog(BuildContext context, HomeNotifier notifier) async {
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
                await notifier.createFolder(name);
                if (context.mounted) {
                  Navigator.pop(context);
                }
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeNotifier>(
      create: (_) => HomeNotifier(),
      child: Consumer<HomeNotifier>(
        builder: (context, notifier, child) {
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
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: (val) => _onSearchChanged(context, val),
                                  decoration: InputDecoration(
                                    hintText: "Search documents or OCR text...",
                                    prefixIcon: const Icon(Icons.search,
                                        color: Color(0xFF00A86B)),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.cancel,
                                                color: Colors.grey),
                                            onPressed: () => _clearSearch(context),
                                          )
                                        : null,
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
                                      children: notifier.folders.map((folder) {
                                        return FolderChip(
                                          folder: folder,
                                          isSelected: notifier.selectedFolderId == folder.id,
                                          onTap: () {
                                            notifier.setSelectedFolderId(
                                              (notifier.selectedFolderId == folder.id)
                                                  ? null
                                                  : folder.id,
                                            );
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showAddFolderDialog(context, notifier),
                                  icon:
                                      const Icon(Icons.add, color: Color(0xFF00A86B)),
                                  label: const Text("+ Folder",
                                      style: TextStyle(color: Color(0xFF00A86B))),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: notifier.isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00A86B),
                                    ),
                                  )
                                : notifier.localFiles.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              notifier.searchQuery.trim().isNotEmpty
                                                  ? Icons.search_off_outlined
                                                  : Icons.folder_open_outlined,
                                              size: 70,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              notifier.searchQuery.trim().isNotEmpty
                                                  ? "No results found for \"${notifier.searchQuery}\"\nTry checking your spelling or using different keywords."
                                                  : "No saved files found.\nTap Scan or ID Card and export to save files!",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 16,
                                                  height: 1.4),
                                            ),
                                            if (notifier.searchQuery.trim().isNotEmpty) ...[
                                              const SizedBox(height: 16),
                                              ElevatedButton.icon(
                                                onPressed: () => _clearSearch(context),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF00A86B),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                icon: const Icon(Icons.clear, size: 18),
                                                label: const Text("Clear Search"),
                                              ),
                                            ],
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        itemCount: notifier.localFiles.length,
                                        itemBuilder: (context, index) {
                                          final item = notifier.localFiles[index];
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
                                              title: _highlightedText(
                                                item.displayTitle,
                                                item.highlightQuery,
                                                baseStyle: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                highlightStyle: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  backgroundColor: Color(0xFFFDE047),
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (item.extractedTextSnippet != null &&
                                                        item.extractedTextSnippet!.isNotEmpty) ...[
                                                      Padding(
                                                        padding: const EdgeInsets.only(bottom: 4.0),
                                                        child: _highlightedText(
                                                          item.extractedTextSnippet!,
                                                          item.highlightQuery,
                                                          baseStyle: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey.shade600,
                                                            fontStyle: FontStyle.italic,
                                                          ),
                                                          highlightStyle: const TextStyle(
                                                            fontSize: 12,
                                                            backgroundColor: Color(0xFFFDE047),
                                                            color: Color(0xFF0F172A),
                                                            fontWeight: FontWeight.bold,
                                                            fontStyle: FontStyle.italic,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    Row(
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
                                                      final deleted = await notifier.deleteFile(file);
                                                      if (context.mounted) {
                                                        if (deleted) {
                                                          ScaffoldMessenger.of(context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                                content: Text(
                                                                    "Deleted '$fileName' successfully.")),
                                                          );
                                                        } else {
                                                          ScaffoldMessenger.of(context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    "Failed to delete file.")),
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
                                                  } else if (action == 'rename') {
                                                    final newName = await showDialog<String>(
                                                      context: context,
                                                      builder: (context) {
                                                        final controller = TextEditingController(text: item.displayTitle);
                                                        return AlertDialog(
                                                          title: const Text("Rename File"),
                                                          content: TextField(
                                                            controller: controller,
                                                            decoration: const InputDecoration(hintText: "Enter new name"),
                                                            textCapitalization: TextCapitalization.sentences,
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.pop(context),
                                                              child: const Text("Cancel"),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () {
                                                                final name = controller.text.trim();
                                                                if (name.isNotEmpty) {
                                                                  Navigator.pop(context, name);
                                                                }
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                  backgroundColor: const Color(0xFF00A86B)),
                                                              child: const Text("Rename", style: TextStyle(color: Colors.white)),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );

                                                    if (newName != null && newName.trim().isNotEmpty) {
                                                      final renamed = await notifier.renameFile(file, newName);
                                                      if (context.mounted) {
                                                        if (renamed) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text("Renamed successfully to '$newName'")),
                                                          );
                                                        } else {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text("Failed to rename file.")),
                                                          );
                                                        }
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
                                                    value: 'rename',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.edit,
                                                            color: Color(0xFF00A86B),
                                                            size: 20),
                                                        SizedBox(width: 8),
                                                        Text('Rename'),
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
                                          onPressed: () => _startIdCardScan(context, notifier),
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
                                          onPressed: () => _startScan(context, notifier),
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
              onTap: (index) {
                setState(() => _activeTab = index);
                if (index == 0) {
                  notifier.loadData();
                }
              },
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
        },
      ),
    );
  }
}
