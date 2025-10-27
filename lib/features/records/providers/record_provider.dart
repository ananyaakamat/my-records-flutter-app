import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../domain/record_model.dart';
import '../../folders/providers/folder_provider.dart';

class RecordNotifier extends StateNotifier<List<RecordModel>> {
  RecordNotifier() : super([]);

  final DatabaseHelper _databaseHelper = DatabaseHelper();

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
    } catch (e) {
      debugPrint('Error updating record: $e');
    }
  }

  Future<void> deleteRecord(int recordId, int folderId, WidgetRef ref) async {
    try {
      await _databaseHelper.delete('records', 'id = ?', [recordId]);
      state = state.where((record) => record.id != recordId).toList();

      // Update folder record count
      await _updateFolderRecordCount(folderId, ref);
    } catch (e) {
      debugPrint('Error deleting record: $e');
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
