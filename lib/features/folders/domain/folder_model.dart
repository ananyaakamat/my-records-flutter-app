import 'package:flutter/material.dart';

class FolderModel {
  final int? id;
  final String name;
  final String? description;
  final Color color;
  final IconData icon;
  final int recordsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FolderModel({
    this.id,
    required this.name,
    this.description,
    required this.color,
    required this.icon,
    this.recordsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  FolderModel copyWith({
    int? id,
    String? name,
    String? description,
    Color? color,
    IconData? icon,
    int? recordsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      recordsCount: recordsCount ?? this.recordsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color.value,
      'icon': icon.codePoint,
      'records_count': recordsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      color: Color(map['color'] ?? 0xFF2196F3),
      icon: IconData(map['icon'] ?? Icons.folder.codePoint,
          fontFamily: 'MaterialIcons'),
      recordsCount: map['records_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  @override
  String toString() {
    return 'FolderModel(id: $id, name: $name, description: $description, color: $color, icon: $icon, recordsCount: $recordsCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.color == color &&
        other.icon == icon &&
        other.recordsCount == recordsCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        color.hashCode ^
        icon.hashCode ^
        recordsCount.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
