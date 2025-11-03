import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/automatic_backup_service.dart';
import '../domain/record_model.dart';
import '../../folders/providers/folder_provider.dart';

class RecordNotifier extends StateNotifier<List<RecordModel>> {
  RecordNotifier() : super([]);

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AutomaticBackupService _automaticBackupService =
      AutomaticBackupService.instance;

  Future<void> loadRecordsForFolder(int folderId) async {
    try {
      final List<Map<String, dynamic>> maps = await _databaseHelper.query(
        'records',
        where: 'folder_id = ?',
        whereArgs: [folderId],
      );
      final records = maps.map((map) => RecordModel.fromMap(map)).toList();
      // Sort alphabetically by field name
      records.sort((a, b) =>
          a.fieldName.toLowerCase().compareTo(b.fieldName.toLowerCase()));
      state = records;
    } catch (e) {
      debugPrint('Error loading records: $e');
    }
  }

  Future<void> addRecord(RecordModel record, WidgetRef ref) async {
    try {
      final now = DateTime.now();
      final recordToAdd = record.copyWith(
        createdAt: now,
        updatedAt: now,
      );

      final id = await _databaseHelper.insert('records', recordToAdd.toMap());
      final newRecord = recordToAdd.copyWith(id: id);

      final updatedList = [...state, newRecord];
      // Sort alphabetically by field name
      updatedList.sort((a, b) =>
          a.fieldName.toLowerCase().compareTo(b.fieldName.toLowerCase()));
      state = updatedList;

      // Update folder record count
      await _updateFolderRecordCount(record.folderId, ref);

      // Trigger automatic backup after record creation
      await _automaticBackupService.triggerRecordBackup(
        operation: 'create',
        recordName: newRecord.fieldName,
      );
    } catch (e) {
      debugPrint('Error adding record: $e');
    }
  }

  Future<void> updateRecord(RecordModel record, WidgetRef ref) async {
    try {
      final updatedRecord = record.copyWith(updatedAt: DateTime.now());

      await _databaseHelper.update(
        'records',
        updatedRecord.toMap(),
        'id = ?',
        [record.id],
      );

      final updatedList =
          state.map((r) => r.id == record.id ? updatedRecord : r).toList();
      // Sort alphabetically by field name to maintain order
      updatedList.sort((a, b) =>
          a.fieldName.toLowerCase().compareTo(b.fieldName.toLowerCase()));
      state = updatedList;

      // Trigger automatic backup after record update
      await _automaticBackupService.triggerRecordBackup(
        operation: 'update',
        recordName: updatedRecord.fieldName,
      );
    } catch (e) {
      debugPrint('Error updating record: $e');
    }
  }

  Future<void> deleteRecord(int recordId, int folderId, WidgetRef ref) async {
    try {
      // Get record name before deletion for logging
      final recordToDelete = state.firstWhere((r) => r.id == recordId);

      await _databaseHelper.delete('records', 'id = ?', [recordId]);
      state = state.where((record) => record.id != recordId).toList();

      // Update folder record count
      await _updateFolderRecordCount(folderId, ref);

      // Trigger automatic backup after record deletion
      await _automaticBackupService.triggerRecordBackup(
        operation: 'delete',
        recordName: recordToDelete.fieldName,
      );
    } catch (e) {
      debugPrint('Error deleting record: $e');
    }
  }

  Future<void> duplicateRecord(
      RecordModel record, int folderId, WidgetRef ref) async {
    try {
      final now = DateTime.now();

      // Extract the base name (remove existing " - Copy" or " - Copy (n)" suffixes)
      String baseName = _extractBaseName(record.fieldName);
      debugPrint(
          'DUPLICATE DEBUG: Original name: "${record.fieldName}", Base name: "$baseName"');

      // Get all existing records in the target folder from database (not from state)
      final List<Map<String, dynamic>> existingMaps =
          await _databaseHelper.query(
        'records',
        where: 'folder_id = ?',
        whereArgs: [folderId],
      );
      final existingRecordsInFolder =
          existingMaps.map((map) => RecordModel.fromMap(map)).toList();
      debugPrint(
          'DUPLICATE DEBUG: Existing records in target folder: ${existingRecordsInFolder.map((r) => r.fieldName).toList()}');

      // Generate a unique name for the duplicate
      String duplicatedFieldName =
          _generateUniqueCopyName(baseName, existingRecordsInFolder);
      debugPrint('DUPLICATE DEBUG: Generated name: "$duplicatedFieldName"');

      final duplicatedRecord = RecordModel(
        fieldName: duplicatedFieldName,
        fieldValues: List.from(record.fieldValues), // Create a copy of the list
        folderId: folderId,
        createdAt: now,
        updatedAt: now,
      );

      final id =
          await _databaseHelper.insert('records', duplicatedRecord.toMap());
      final newRecord = duplicatedRecord.copyWith(id: id);

      final updatedList = [...state, newRecord];
      // Sort alphabetically by field name
      updatedList.sort((a, b) =>
          a.fieldName.toLowerCase().compareTo(b.fieldName.toLowerCase()));
      state = updatedList;

      // Update folder record count
      await _updateFolderRecordCount(folderId, ref);

      // Trigger automatic backup after record duplication
      await _automaticBackupService.triggerRecordBackup(
        operation: 'duplicate',
        recordName: newRecord.fieldName,
      );
    } catch (e) {
      debugPrint('Error duplicating record: $e');
    }
  }

  /// Extracts the base name from a field name by removing " - Copy" or " - Copy (n)" suffixes
  String _extractBaseName(String fieldName) {
    // Remove " - Copy (n)" pattern first
    String baseName = fieldName.replaceAll(RegExp(r' - Copy \(\d+\)$'), '');

    // Remove " - Copy" pattern
    if (baseName.endsWith(' - Copy')) {
      baseName = baseName.substring(0, baseName.length - ' - Copy'.length);
    }

    return baseName;
  }

  /// Generates a unique copy name following the pattern: baseName, baseName - Copy, baseName - Copy (2), etc.
  String _generateUniqueCopyName(
      String baseName, List<RecordModel> existingRecords) {
    // Create a set of existing names for faster lookup
    final existingNames =
        existingRecords.map((r) => r.fieldName.toLowerCase()).toSet();

    // Check if the base name itself is available
    if (!existingNames.contains(baseName.toLowerCase())) {
      return baseName;
    }

    // Check "baseName - Copy"
    String copyName = '$baseName - Copy';
    if (!existingNames.contains(copyName.toLowerCase())) {
      return copyName;
    }

    // Check "baseName - Copy (2)", "baseName - Copy (3)", etc.
    int copyNumber = 2;
    while (true) {
      String numberedCopyName = '$baseName - Copy ($copyNumber)';
      if (!existingNames.contains(numberedCopyName.toLowerCase())) {
        return numberedCopyName;
      }
      copyNumber++;
    }
  }

  Future<void> _updateFolderRecordCount(int folderId, WidgetRef ref) async {
    try {
      final List<Map<String, dynamic>> countResult = await _databaseHelper
          .query('records', where: 'folder_id = ?', whereArgs: [folderId]);

      final newCount = countResult.length;
      await ref
          .read(folderProvider.notifier)
          .updateRecordCount(folderId, newCount);
    } catch (e) {
      debugPrint('Error updating folder record count: $e');
    }
  }

  void clearState() {
    state = [];
  }
}

final recordProvider =
    StateNotifierProvider<RecordNotifier, List<RecordModel>>((ref) {
  return RecordNotifier();
});

// Provider for getting record count for a specific folder
final recordCountProvider = Provider.family<int, int>((ref, folderId) {
  final records = ref.watch(recordProvider);
  return records.where((record) => record.folderId == folderId).length;
});
