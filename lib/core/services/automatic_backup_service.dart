import 'package:flutter/foundation.dart';
import 'backup_service.dart';

/// Service to handle automatic backups triggered by data operations
class AutomaticBackupService {
  static AutomaticBackupService? _instance;
  static AutomaticBackupService get instance {
    _instance ??= AutomaticBackupService._internal();
    return _instance!;
  }

  AutomaticBackupService._internal();

  final BackupService _backupService = BackupService.instance;

  /// Triggers an automatic backup after any data operation
  /// This method is called after create, update, duplicate, or delete operations
  Future<void> triggerAutomaticBackup({
    required String operation,
    required String entityType,
    String? entityName,
  }) async {
    try {
      if (kDebugMode) {
        print(
            'AutomaticBackup: Triggering backup after $operation $entityType${entityName != null ? ' "$entityName"' : ''}');
      }

      // Check if there are folders to backup before creating backup
      final hasFolders = await _backupService.hasFoldersToBackup();
      if (!hasFolders) {
        if (kDebugMode) {
          print('AutomaticBackup: Skipping backup - no folders to backup');
        }
        return;
      }

      // Create automatic backup
      final result = await _backupService.createBackup(isAutoBackup: true);

      if (result['filePath'].toString().isNotEmpty) {
        if (kDebugMode) {
          final stats = result['stats'] as Map<String, dynamic>;
          print(
              'AutomaticBackup: Backup created successfully after $operation $entityType');
          print(
              'AutomaticBackup: Backup contains ${stats['folders']} folders and ${stats['records']} records');
          print('AutomaticBackup: Backup file: ${result['filePath']}');
        }
      } else {
        if (kDebugMode) {
          print('AutomaticBackup: Backup skipped - no data to backup');
        }
      }
    } catch (e) {
      // Don't throw the error as it shouldn't break the main operation
      // Just log it for debugging
      if (kDebugMode) {
        print(
            'AutomaticBackup: Failed to create automatic backup after $operation $entityType: $e');
      }
    }
  }

  /// Triggers backup after folder operations
  Future<void> triggerFolderBackup({
    required String operation,
    String? folderName,
  }) async {
    await triggerAutomaticBackup(
      operation: operation,
      entityType: 'folder',
      entityName: folderName,
    );
  }

  /// Triggers backup after record operations
  Future<void> triggerRecordBackup({
    required String operation,
    String? recordName,
  }) async {
    await triggerAutomaticBackup(
      operation: operation,
      entityType: 'record',
      entityName: recordName,
    );
  }
}
