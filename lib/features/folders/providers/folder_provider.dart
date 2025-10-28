import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../domain/folder_model.dart';

class FolderNotifier extends StateNotifier<List<FolderModel>> {
  FolderNotifier() : super([]) {
    loadFolders();
  }

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<void> loadFolders() async {
    try {
      final List<Map<String, dynamic>> maps =
          await _databaseHelper.query('folders');
      final folders = maps.map((map) => FolderModel.fromMap(map)).toList();
      folders.sort(
          (a, b) => a.sortOrder.compareTo(b.sortOrder)); // Sort by sortOrder
      state = folders;
    } catch (e) {
      debugPrint('Error loading folders: $e');
    }
  }

  Future<void> addFolder(FolderModel folder) async {
    try {
      final now = DateTime.now();
      final maxSortOrder = state.isEmpty
          ? 0
          : state.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

      final folderToAdd = folder.copyWith(
        createdAt: now,
        updatedAt: now,
        sortOrder: maxSortOrder + 1,
      );

      final id = await _databaseHelper.insert('folders', folderToAdd.toMap());
      final newFolder = folderToAdd.copyWith(id: id);

      state = [newFolder, ...state];
    } catch (e) {
      debugPrint('Error adding folder: $e');
    }
  }

  Future<void> updateFolder(FolderModel folder) async {
    try {
      final updatedFolder = folder.copyWith(updatedAt: DateTime.now());

      await _databaseHelper.update(
        'folders',
        updatedFolder.toMap(),
        'id = ?',
        [folder.id],
      );

      state = state.map((f) => f.id == folder.id ? updatedFolder : f).toList();

      // Re-sort by sort order
      final sortedFolders = List<FolderModel>.from(state);
      sortedFolders.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      state = sortedFolders;
    } catch (e) {
      debugPrint('Error updating folder: $e');
    }
  }

  Future<void> deleteFolder(int folderId) async {
    try {
      await _databaseHelper.delete('folders', 'id = ?', [folderId]);
      state = state.where((folder) => folder.id != folderId).toList();
    } catch (e) {
      debugPrint('Error deleting folder: $e');
    }
  }

  Future<void> duplicateFolder(FolderModel folder) async {
    try {
      final duplicatedFolder = FolderModel(
        name: '${folder.name} (Copy)',
        description: folder.description,
        color: folder.color,
        icon: folder.icon,
        recordsCount: 0, // New folder starts with 0 records
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addFolder(duplicatedFolder);
    } catch (e) {
      debugPrint('Error duplicating folder: $e');
    }
  }

  Future<void> updateRecordCount(int folderId, int newCount) async {
    try {
      final folder = state.firstWhere((f) => f.id == folderId);
      final updatedFolder = folder.copyWith(
        recordsCount: newCount,
        updatedAt: DateTime.now(),
      );

      await updateFolder(updatedFolder);
    } catch (e) {
      debugPrint('Error updating record count: $e');
    }
  }

  Future<void> deleteAllFolders() async {
    try {
      // Delete all records first (due to foreign key constraint)
      await _databaseHelper.delete('records', '1=1', []);
      // Delete all folders
      await _databaseHelper.delete('folders', '1=1', []);
      // Clear the state
      state = [];
    } catch (e) {
      debugPrint('Error deleting all folders: $e');
    }
  }
}

final folderProvider =
    StateNotifierProvider<FolderNotifier, List<FolderModel>>((ref) {
  return FolderNotifier();
});

// Computed provider for folder count
final folderCountProvider = Provider<int>((ref) {
  final folders = ref.watch(folderProvider);
  return folders.length;
});

// Computed provider for total records count
final totalRecordsCountProvider = Provider<int>((ref) {
  final folders = ref.watch(folderProvider);
  return folders.fold(0, (total, folder) => total + folder.recordsCount);
});
