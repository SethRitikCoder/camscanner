class FolderModel {
  final int? id;
  final String name;
  final String colorHex;
  final int createdAt;

  FolderModel({
    this.id,
    required this.name,
    this.colorHex = '#00A86B',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'createdAt': createdAt,
    };
  }

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorHex: map['colorHex'] as String? ?? '#00A86B',
      createdAt: map['createdAt'] as int,
    );
  }
}
