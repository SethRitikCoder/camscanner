import 'package:flutter/material.dart';
import '../models/folder_model.dart';

class FolderChip extends StatelessWidget {
  final FolderModel folder;
  final bool isSelected;
  final VoidCallback onTap;

  const FolderChip({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(folder.name),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFE6F6F0),
        checkmarkColor: const Color(0xFF00A86B),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF00A86B) : const Color(0xFF0F172A),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF00A86B) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
