import 'dart:convert';

class RecordModel {
  final int? id;
  final int folderId;
  final String fieldName;
  final List<String> fieldValues;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecordModel({
    this.id,
    required this.folderId,
    required this.fieldName,
    required this.fieldValues,
    required this.createdAt,
    required this.updatedAt,
  });

  RecordModel copyWith({
    int? id,
    int? folderId,
    String? fieldName,
    List<String>? fieldValues,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecordModel(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      fieldName: fieldName ?? this.fieldName,
      fieldValues: fieldValues ?? this.fieldValues,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folder_id': folderId,
      'field_name': fieldName,
      'field_value': jsonEncode(fieldValues),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory RecordModel.fromMap(Map<String, dynamic> map) {
    return RecordModel(
      id: map['id'],
      folderId: map['folder_id'],
      fieldName: map['field_name'] ?? '',
      fieldValues: _parseFieldValues(map['field_value']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  static List<String> _parseFieldValues(dynamic fieldValue) {
    if (fieldValue is String) {
      try {
        // Try to parse as JSON array
        final decoded = jsonDecode(fieldValue);
        if (decoded is List) {
          return decoded.cast<String>();
        }
      } catch (e) {
        // If JSON parsing fails, treat as single value
      }
      // Single value or invalid JSON, return as single item list
      return [fieldValue];
    }
    return [];
  }

  @override
  String toString() {
    return 'RecordModel(id: $id, folderId: $folderId, fieldName: $fieldName, fieldValues: $fieldValues, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordModel &&
        other.id == id &&
        other.folderId == folderId &&
        other.fieldName == fieldName &&
        _listEquals(other.fieldValues, fieldValues) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        folderId.hashCode ^
        fieldName.hashCode ^
        fieldValues.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  // Getter for backward compatibility and easy access to display value
  String get fieldValue => fieldValues.isNotEmpty ? fieldValues.first : '';
}
