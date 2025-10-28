import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../database/database_helper.dart'; // WorkManager callback for background backup task

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (kDebugMode) {
        print('WorkManager task received: $task');
      }
      if (task == "auto_backup_task") {
        if (kDebugMode) {
          print('Executing auto backup task...');
        }
        final backupService = BackupService._internal();
        final result = await backupService.createBackup(isAutoBackup: true);

        if (kDebugMode) {
          print(
              'Auto backup result: ${result.isNotEmpty ? "SUCCESS" : "SKIPPED"}');
        }

        // Always return true for auto backup to keep the periodic task running
        return Future.value(true);
      }
      if (kDebugMode) {
        print('Unknown task: $task');
      }
      return Future.value(false);
    } catch (e) {
      if (kDebugMode) {
        print('Auto backup failed: $e');
      }
      // Return true even on error to keep periodic task running
      return Future.value(true);
    }
  });
}

class BackupService {
  static const String _backupFolderName = 'my_records';
  static const int _maxBackupFiles = 3;
  static const String _autoBackupKey = 'auto_backup_enabled';
  static const String _autoBackupFrequencyKey = 'auto_backup_frequency';
  static const String _lastBackupKey = 'last_backup_timestamp';

  static BackupService? _instance;
  static BackupService get instance {
    _instance ??= BackupService._internal();
    return _instance!;
  }

  BackupService._internal();

  // Initialize backup service
  Future<void> initialize() async {
    await _initializeWorkManager();
  }

  // Initialize WorkManager for auto-backup
  Future<void> _initializeWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  // Get Downloads folder path
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // For Android, use the Downloads directory
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Navigate to the Downloads folder
        const downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);
        if (await downloadsDir.exists()) {
          return downloadsDir;
        }
      }
      // Fallback to external storage directory
      return directory ?? await getApplicationDocumentsDirectory();
    } else {
      // For other platforms, use documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  // Create backup folder in Downloads
  Future<Directory> _createBackupFolder() async {
    final downloadsDir = await _getDownloadsDirectory();
    final backupDir = Directory('${downloadsDir.path}/$_backupFolderName');

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  // Public method to get backup directory for external access
  Future<Directory> getBackupDirectory() async {
    return await _createBackupFolder();
  }

  Future<String> createBackup({bool isAutoBackup = false}) async {
    try {
      final dbHelper = DatabaseHelper();

      // Get all folders from database
      final folders = await dbHelper.query('folders');

      // Check if there are existing folders - only create backup if folders exist
      if (folders.isEmpty) {
        if (isAutoBackup) {
          // For auto backup, just skip silently
          if (kDebugMode) {
            print('Auto-backup skipped: No folders to backup');
          }
          return '';
        }
        throw Exception(
            'No folders found. Create some folders with records before creating a backup.');
      }

      // Get all records from database (includes records for all folders)
      final records = await dbHelper.query('records');

      // Create backup data structure with all folders and their respective records
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'folders': folders,
        'records': records,
        'totalFolders': folders.length,
        'totalRecords': records.length,
      };

      // Create backup filename with 12-hour format
      final timestamp = DateTime.now();
      final hour12 = timestamp.hour > 12
          ? timestamp.hour - 12
          : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final amPM = timestamp.hour >= 12 ? 'PM' : 'AM';
      final formattedDate =
          "${timestamp.day}${_getMonthName(timestamp.month)}${timestamp.year.toString().substring(2)}_${hour12.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}$amPM";
      final filename = 'my_records$formattedDate.json';

      // Get backup folder
      final backupDir = await _createBackupFolder();
      final filePath = '${backupDir.path}/$filename';

      // Write backup file
      final file = File(filePath);
      await file.writeAsString(jsonEncode(backupData));

      // Clean up old backups
      await _cleanupOldBackupsInDirectory(backupDir);

      // Update last backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, timestamp.toIso8601String());

      if (kDebugMode && isAutoBackup) {
        debugPrint('Auto backup completed successfully: $filename');
      }

      return filePath;
    } catch (e) {
      if (kDebugMode) {
        print('Backup error: $e');
      }
      throw Exception('Failed to create backup: $e');
    }
  }

  Future<void> restoreFromBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }

      final content = await file.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      // Validate backup structure - must contain folders and records
      if (!backupData.containsKey('folders') ||
          !backupData.containsKey('records')) {
        throw Exception(
            'Invalid backup file format - missing folders or records data');
      }

      final folders = backupData['folders'] as List;
      final records = backupData['records'] as List;

      // Validate that backup contains folders (since we only create backups when folders exist)
      if (folders.isEmpty) {
        throw Exception('Invalid backup file - no folders found in backup');
      }

      final dbHelper = DatabaseHelper();

      // Clear existing data (records first to maintain referential integrity)
      await dbHelper.delete('records', '1 = 1', []);
      await dbHelper.delete('folders', '1 = 1', []);

      // Restore folders first
      for (final folder in folders) {
        await dbHelper.insert('folders', folder as Map<String, dynamic>);
      }

      // Restore records that belong to the folders
      for (final record in records) {
        await dbHelper.insert('records', record as Map<String, dynamic>);
      }

      // Log restoration info for debugging
      if (kDebugMode) {
        print(
            'Backup restored successfully: ${folders.length} folders, ${records.length} records');
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  Future<List<String>> getAvailableBackups() async {
    try {
      final backupDir = await getBackupDirectory();
      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir
          .list()
          .where((entity) =>
              entity is File &&
              entity.path.endsWith('.json') &&
              path.basename(entity.path).startsWith('my_records'))
          .cast<File>()
          .toList();

      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return files.map((file) => file.path).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting available backups: $e');
      }
      return [];
    }
  }

  Future<void> shareBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'My Records Backup',
        subject: 'My Records App Backup File',
      );
    } catch (e) {
      throw Exception('Failed to share backup: $e');
    }
  }

  /// Check if there are existing folders in the database
  /// Returns true if folders exist, false otherwise
  Future<bool> hasFoldersToBackup() async {
    try {
      final dbHelper = DatabaseHelper();
      final folders = await dbHelper.query('folders');
      return folders.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get backup statistics for display
  Future<Map<String, int>> getBackupStats() async {
    try {
      final dbHelper = DatabaseHelper();
      final folders = await dbHelper.query('folders');
      final records = await dbHelper.query('records');

      return {
        'folders': folders.length,
        'records': records.length,
      };
    } catch (e) {
      return {'folders': 0, 'records': 0};
    }
  }

  String getBackupFileName(String filePath) {
    return path.basename(filePath);
  }

  Future<DateTime?> getBackupDate(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      if (backupData.containsKey('timestamp')) {
        return DateTime.parse(backupData['timestamp']);
      }

      return file.statSync().modified;
    } catch (e) {
      return null;
    }
  }

  // Get backup settings
  Future<Map<String, dynamic>> getBackupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'auto_backup_enabled': prefs.getBool(_autoBackupKey) ?? false,
      'auto_backup_frequency':
          prefs.getString(_autoBackupFrequencyKey) ?? 'daily',
      'last_backup': prefs.getString(_lastBackupKey),
    };
  }

  // Get last backup info
  Future<String?> getLastBackupInfo() async {
    try {
      final backupFiles = await getAvailableBackups();

      if (backupFiles.isEmpty) {
        return 'No backup created yet';
      }

      // Get the most recent backup file path
      final lastBackupPath = backupFiles.first;
      final lastBackupFile = File(lastBackupPath);
      final lastModified = lastBackupFile.lastModifiedSync();
      final now = DateTime.now();
      final difference = now.difference(lastModified);

      String timeAgo;
      if (difference.inDays > 0) {
        timeAgo =
            '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        timeAgo =
            '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        timeAgo =
            '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        timeAgo = 'Just now';
      }

      return 'Last backup: $timeAgo';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting last backup info: $e');
      }
      return 'No backup created yet';
    }
  }

  // Auto-backup settings
  Future<void> setAutoBackup(bool enabled, String frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, enabled);
    await prefs.setString(_autoBackupFrequencyKey, frequency);

    // Always cancel existing tasks first
    await Workmanager().cancelByUniqueName('auto_backup');

    if (enabled) {
      await _scheduleAutoBackup(frequency);
    }
  }

  // Schedule auto-backup
  Future<void> _scheduleAutoBackup(String frequency) async {
    if (kDebugMode) {
      print('Scheduling auto backup with frequency: $frequency');
    }

    Duration interval;
    switch (frequency.toLowerCase()) {
      case 'daily':
        interval = const Duration(days: 1);
        break;
      case 'weekly':
        interval = const Duration(days: 7);
        break;
      default:
        interval = const Duration(days: 1);
    }

    if (kDebugMode) {
      print(
          'Registering periodic task with interval: ${interval.inMinutes} minutes');
    }

    await Workmanager().registerPeriodicTask(
      'auto_backup',
      'auto_backup_task',
      frequency: interval,
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );

    if (kDebugMode) {
      print('Auto backup task registered successfully');
    }
  }

  // Force reset auto backup system
  Future<void> forceResetAutoBackup() async {
    try {
      // Cancel all WorkManager tasks
      await Workmanager().cancelAll();
      await Workmanager().cancelByUniqueName('auto_backup');

      if (kDebugMode) {
        print('All auto backup tasks cancelled and reset');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during force reset: $e');
      }
    }
  }

  // Clean old backups (keep only latest 3)
  Future<void> _cleanupOldBackupsInDirectory(Directory backupDir) async {
    try {
      final files = await backupDir.list().toList();

      final backupFiles = files
          .where((file) =>
              file is File &&
              file.path.endsWith('.json') &&
              path.basename(file.path).startsWith('my_records'))
          .cast<File>()
          .toList();

      if (backupFiles.length > _maxBackupFiles) {
        // Sort by modification time (oldest first)
        backupFiles.sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));

        // Delete oldest files, keep only latest 3
        final filesToDelete =
            backupFiles.take(backupFiles.length - _maxBackupFiles);
        for (final file in filesToDelete) {
          await file.delete();
          if (kDebugMode) {
            print('Deleted old backup: ${file.path}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning old backups: $e');
      }
    }
  }

  // Helper method to get month name
  String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }
}
