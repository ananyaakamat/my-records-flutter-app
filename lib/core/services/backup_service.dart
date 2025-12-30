import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Key;
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';

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
              'Auto backup result: ${result['filePath'].isNotEmpty ? "SUCCESS" : "SKIPPED"}');
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

  static const String _autoBackupKey = 'auto_backup_enabled';
  static const String _autoBackupFrequencyKey = 'auto_backup_frequency';
  static const String _lastBackupKey = 'last_backup_timestamp';

  // Encryption constants
  static const String _deviceKeyStorageKey = 'backup_device_key';

  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits
  static const int _saltLength = 32; // 256 bits
  static const int _pbkdf2Iterations = 100000;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

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

  // Check and request storage permissions
  Future<bool> checkStoragePermission() async {
    if (!Platform.isAndroid) {
      return true; // No permission needed on other platforms
    }

    // Check Android version
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // For Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // Fallback to legacy storage permissions
    if (await Permission.storage.isGranted) {
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  // Get Downloads folder path
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Ensure we have storage permission
      await checkStoragePermission();

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

  Future<Map<String, dynamic>> createBackup(
      {bool isAutoBackup = false, String? password}) async {
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
          return {
            'filePath': '',
            'stats': {'folders': 0, 'records': 0}
          };
        }
        throw Exception(
            'No folders found. Create some folders with records before creating a backup.');
      }

      // Get all records from database (includes records for all folders)
      final allRecords = await dbHelper.query('records');

      // Filter records to only include those that belong to existing folders
      final folderIds = folders.map((f) => f['id'] as int).toSet();
      final records = allRecords
          .where((r) => folderIds.contains(r['folder_id'] as int))
          .toList();

      // Debug logging
      if (kDebugMode) {
        print(
            'DEBUG: Found ${allRecords.length} total records, ${records.length} valid records for ${folders.length} folders');
        print('DEBUG: Folder IDs: ${folders.map((f) => f['id']).toList()}');
        print(
            'DEBUG: Valid Records: ${records.map((r) => 'ID:${r['id']} - "${r['field_name']}" (folder: ${r['folder_id']})').toList()}');

        // Check for orphaned records and clean them up
        final orphanedRecords = allRecords
            .where((r) => !folderIds.contains(r['folder_id'] as int))
            .toList();
        if (orphanedRecords.isNotEmpty) {
          print(
              'DEBUG: Found ${orphanedRecords.length} orphaned records (cleaning up): ${orphanedRecords.map((r) => 'ID:${r['id']} - "${r['field_name']}" (folder: ${r['folder_id']})').toList()}');

          // Clean up orphaned records from the database
          for (final orphanedRecord in orphanedRecords) {
            await dbHelper.delete('records', 'id = ?', [orphanedRecord['id']]);
          }

          print(
              'DEBUG: Cleaned up ${orphanedRecords.length} orphaned records from database');
        }
      }

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
      final filename = 'my_records$formattedDate.db.enc';

      // Get backup folder
      final backupDir = await _createBackupFolder();
      final filePath = '${backupDir.path}/$filename';

      // Encrypt backup data with default password
      final jsonData = jsonEncode(backupData);
      final encryptedData = await _encryptData(jsonData, password: '301976');

      // Write encrypted backup file
      final file = File(filePath);
      await file.writeAsString(jsonEncode(encryptedData));

      // Clean up old backups
      await _cleanOldBackups(backupDir);

      // Update last backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, timestamp.toIso8601String());

      if (kDebugMode && isAutoBackup) {
        debugPrint('Auto backup completed successfully: $filename');
      }

      return {
        'filePath': filePath,
        'stats': {
          'folders': folders.length,
          'records': records.length,
        }
      };
    } catch (e) {
      if (kDebugMode) {
        print('Backup error: $e');
      }
      throw Exception('Failed to create backup: $e');
    }
  }

  Future<void> restoreFromBackup(String filePath, {String? password}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }

      final content = await file.readAsString();
      final rawData = jsonDecode(content) as Map<String, dynamic>;

      Map<String, dynamic> backupData;

      // Check if this is an encrypted backup
      if (rawData.containsKey('encrypted_data') && rawData.containsKey('iv')) {
        if (kDebugMode) {
          print('Restore: Processing encrypted backup file');
          print(
              'Restore: is_password_protected = ${rawData['is_password_protected']}');
          print('Restore: has salt = ${rawData['salt'] != null}');
        }
        // Decrypt the backup data using default password if none provided
        final decryptPassword = password ?? '301976';
        if (kDebugMode) {
          print('Restore: Using password for decryption: $decryptPassword');
        }
        final decryptedJson =
            await _decryptData(rawData, password: decryptPassword);
        backupData = jsonDecode(decryptedJson) as Map<String, dynamic>;
      } else {
        if (kDebugMode) {
          print('Restore: Processing legacy unencrypted backup file');
        }
        // This is a legacy unencrypted backup
        backupData = rawData;
      }

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
      // Check permissions first
      final hasPermission = await checkStoragePermission();
      if (!hasPermission) {
        if (kDebugMode) {
          debugPrint('Storage permission not granted');
        }
        return [];
      }

      final backupDir = await getBackupDirectory();
      if (kDebugMode) {
        debugPrint('Scanning backup directory: ${backupDir.path}');
      }

      if (!await backupDir.exists()) {
        if (kDebugMode) {
          debugPrint('Backup directory does not exist');
        }
        return [];
      }

      // Force directory refresh by creating a new Directory instance
      // This helps avoid cached directory listings
      final freshDir = Directory(backupDir.path);

      // List all files in the directory using direct path reading
      final List<FileSystemEntity> allEntities = [];
      try {
        await for (var entity
            in freshDir.list(recursive: false, followLinks: false)) {
          allEntities.add(entity);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error listing directory: $e');
        }
      }

      if (kDebugMode) {
        debugPrint('Found ${allEntities.length} entities in backup directory');
        for (var entity in allEntities) {
          debugPrint(
              '  - ${path.basename(entity.path)} (${entity.runtimeType})');
        }
      }

      // Filter for valid backup files
      final List<File> files = [];
      for (var entity in allEntities) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          if (kDebugMode) {
            debugPrint('Checking file: $fileName');
          }

          // Accept .db.enc files that contain 'my_record' (case-insensitive)
          // This catches both 'my_records*.db.enc' and 'My Records Backup - my_records*.db.enc'
          if (fileName.toLowerCase().endsWith('.db.enc') &&
              fileName.toLowerCase().contains('my_record')) {
            // Create a fresh File instance to avoid caching
            final freshFile = File(entity.path);
            // Verify file actually exists and is readable
            try {
              final exists = await freshFile.exists();
              if (exists) {
                // Try to get file stats to ensure it's readable
                final stat = await freshFile.stat();
                if (kDebugMode) {
                  debugPrint(
                      'Valid backup file: $fileName (${stat.size} bytes, modified: ${stat.modified})');
                }
                files.add(freshFile);
              } else {
                if (kDebugMode) {
                  debugPrint('File does not exist: $fileName');
                }
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error accessing file $fileName: $e');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint('Found ${files.length} valid backup files');
      }

      // Sort by modification time (newest first)
      files.sort((a, b) {
        try {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error sorting files: $e');
          }
          return 0;
        }
      });

      return files.map((file) => file.path).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting available backups: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
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

  /// Scan the backup directory for manually copied files
  /// This method performs a thorough scan to detect files that may have been
  /// copied to the backup folder from external sources
  Future<void> scanForExternalBackups() async {
    try {
      final backupDir = await getBackupDirectory();
      if (!await backupDir.exists()) {
        if (kDebugMode) {
          debugPrint('Backup directory does not exist, creating...');
        }
        await backupDir.create(recursive: true);
        return;
      }

      if (kDebugMode) {
        debugPrint('Scanning for external backup files...');
      }

      // Force directory refresh by re-checking existence
      final dirExists = await backupDir.exists();
      if (!dirExists) {
        if (kDebugMode) {
          debugPrint('Backup directory not accessible');
        }
        return;
      }

      // List all files directly without filtering
      final allFiles = <FileSystemEntity>[];
      await for (var entity
          in backupDir.list(recursive: false, followLinks: false)) {
        allFiles.add(entity);
      }

      if (kDebugMode) {
        debugPrint(
            'Found ${allFiles.length} total entities in backup directory');
        for (var file in allFiles) {
          if (file is File) {
            final fileName = path.basename(file.path);
            final fileExists = await file.exists();
            if (kDebugMode) {
              debugPrint('  File: $fileName (exists: $fileExists)');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error scanning for external backups: $e');
      }
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

  // Clean old backups (keep only latest 3) - Health app approach
  Future<void> _cleanOldBackups(Directory backupDir) async {
    try {
      final files = await backupDir.list().toList();

      // Clean up any existing JSON files (legacy from previous versions)
      final jsonFiles = files
          .where((file) => file is File && file.path.endsWith('.json.enc'))
          .cast<File>()
          .toList();

      for (final jsonFile in jsonFiles) {
        await jsonFile.delete();
        debugPrint('Removed legacy JSON backup file: ${jsonFile.path}');
      }

      final backupFiles = files
          .where((file) => file is File && file.path.endsWith('.db.enc'))
          .cast<File>()
          .toList();

      if (backupFiles.length > 3) {
        // Sort by modification time (oldest first)
        backupFiles.sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));

        // Delete oldest files, keep only latest 3
        final filesToDelete = backupFiles.take(backupFiles.length - 3);
        for (final file in filesToDelete) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning old backups: $e');
    }
  }

  // Public method to manually trigger cleanup for testing
  Future<void> testCleanupOldBackups() async {
    try {
      final backupDir = await getBackupDirectory();
      if (await backupDir.exists()) {
        await _cleanOldBackups(backupDir);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Test cleanup error: $e');
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

  // ===== ENCRYPTION METHODS =====

  /// Generate or retrieve device-specific encryption key
  Future<Uint8List> _getOrCreateDeviceKey() async {
    try {
      final existingKey = await _secureStorage.read(key: _deviceKeyStorageKey);

      if (existingKey != null) {
        return base64Decode(existingKey);
      }

      // Generate new device key
      final random = Random.secure();
      final key = Uint8List(_keyLength);
      for (int i = 0; i < _keyLength; i++) {
        key[i] = random.nextInt(256);
      }

      // Store device key securely
      await _secureStorage.write(
        key: _deviceKeyStorageKey,
        value: base64Encode(key),
      );

      return key;
    } catch (e) {
      if (kDebugMode) {
        print('Error generating/retrieving device key: $e');
      }
      rethrow;
    }
  }

  /// Generate key from password using PBKDF2
  Uint8List _generateKeyFromPassword(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);

    // Use PBKDF2 with HMAC-SHA256
    var key = Uint8List.fromList(passwordBytes);
    for (int i = 0; i < _pbkdf2Iterations; i++) {
      var hmac = Hmac(sha256, key);
      final combined = Uint8List.fromList([...salt, ...utf8.encode(password)]);
      key = Uint8List.fromList(hmac.convert(combined).bytes);
    }

    // Ensure key is exactly the required length
    if (key.length > _keyLength) {
      return Uint8List.fromList(key.take(_keyLength).toList());
    } else if (key.length < _keyLength) {
      // Pad with zeros if needed
      final paddedKey = Uint8List(_keyLength);
      paddedKey.setRange(0, key.length, key);
      return paddedKey;
    }

    return key;
  }

  /// Generate random salt for password-based encryption
  Uint8List _generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(_saltLength);
    for (int i = 0; i < _saltLength; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Generate random IV for encryption
  Uint8List _generateIV() {
    final random = Random.secure();
    final iv = Uint8List(_ivLength);
    for (int i = 0; i < _ivLength; i++) {
      iv[i] = random.nextInt(256);
    }
    return iv;
  }

  /// Encrypt data using AES-256-CBC
  Future<Map<String, dynamic>> _encryptData(String data,
      {String? password}) async {
    try {
      final iv = _generateIV();
      Uint8List key;
      Uint8List? salt;

      if (password != null) {
        // Use password-based encryption for cross-device compatibility
        salt = _generateSalt();
        key = _generateKeyFromPassword(password, salt);
      } else {
        // Use device-specific key
        key = await _getOrCreateDeviceKey();
      }

      final encrypter = Encrypter(AES(Key(key)));
      final encrypted = encrypter.encrypt(data, iv: IV(iv));

      return {
        'encrypted_data': encrypted.base64,
        'iv': base64Encode(iv),
        'salt': salt != null ? base64Encode(salt) : null,
        'is_password_protected': password != null,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Encryption error: $e');
      }
      rethrow;
    }
  }

  /// Decrypt data using AES-256-CBC
  Future<String> _decryptData(Map<String, dynamic> encryptedData,
      {String? password}) async {
    try {
      final encryptedBase64 = encryptedData['encrypted_data'] as String;
      final ivBase64 = encryptedData['iv'] as String;
      final saltBase64 = encryptedData['salt'] as String?;
      final isPasswordProtected =
          encryptedData['is_password_protected'] as bool? ?? false;

      final iv = base64Decode(ivBase64);
      Uint8List key;

      if (isPasswordProtected && saltBase64 != null) {
        if (kDebugMode) {
          print('Decrypt: Using password-based decryption');
        }
        if (password == null) {
          throw Exception('Password required for decryption');
        }
        final salt = base64Decode(saltBase64);
        key = _generateKeyFromPassword(password, salt);
      } else {
        if (kDebugMode) {
          print('Decrypt: Using device-specific key decryption');
        }
        // Use device-specific key
        key = await _getOrCreateDeviceKey();
      }

      final encrypter = Encrypter(AES(Key(key)));
      final encrypted = Encrypted.fromBase64(encryptedBase64);
      final decrypted = encrypter.decrypt(encrypted, iv: IV(iv));

      return decrypted;
    } catch (e) {
      if (kDebugMode) {
        print('Decryption error: $e');
      }
      rethrow;
    }
  }

  /// Check if a backup file is encrypted
  Future<bool> isBackupEncrypted(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      return data.containsKey('encrypted_data') && data.containsKey('iv');
    } catch (e) {
      return false;
    }
  }

  /// Check if backup requires password (cross-device backup)
  Future<bool> requiresPassword(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      return data['is_password_protected'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Restore backup with password (for cross-device restores)
  Future<({bool success, String message})> restoreBackupWithPassword(
    String filePath,
    String password,
  ) async {
    try {
      await restoreFromBackup(filePath, password: password);
      return (success: true, message: 'Backup restored successfully');
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Password required') ||
          errorMessage.contains('Decryption error')) {
        return (success: false, message: 'Invalid password. Please try again.');
      } else if (errorMessage.contains('Invalid backup file format')) {
        return (success: false, message: 'Invalid backup file format.');
      } else {
        return (
          success: false,
          message: 'Failed to restore backup: $errorMessage'
        );
      }
    }
  }

  /// Create backup with password for cross-device compatibility
  Future<Map<String, dynamic>> createPasswordProtectedBackup(
      String password) async {
    return await createBackup(password: password);
  }

  /// Get backup info including encryption status
  Future<Map<String, dynamic>> getBackupInfo(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file not found');
    }

    final stat = await file.stat();
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    // Check if encrypted
    final isEncrypted =
        data.containsKey('encrypted_data') && data.containsKey('iv');
    final isPasswordProtected = data['is_password_protected'] as bool? ?? false;

    Map<String, dynamic>? actualBackupData;
    if (!isEncrypted) {
      // Legacy unencrypted backup
      actualBackupData = data;
    }

    return {
      'filename': path.basename(filePath),
      'size': stat.size,
      'created': stat.modified,
      'is_encrypted': isEncrypted,
      'is_password_protected': isPasswordProtected,
      'requires_password': isPasswordProtected,
      'folder_count': actualBackupData?['totalFolders'] ?? 0,
      'record_count': actualBackupData?['totalRecords'] ?? 0,
      'version': actualBackupData?['version'] ?? '1.0',
    };
  }

  /// Manually force cleanup of old backup files
  /// This method can be called to ensure only the latest 3 backups are kept
  Future<void> forceCleanupOldBackups() async {
    try {
      final backupDir = await getBackupDirectory();
      if (await backupDir.exists()) {
        await _cleanOldBackups(backupDir);
        if (kDebugMode) {
          print('Manual backup cleanup completed successfully');
        }
      } else {
        if (kDebugMode) {
          print('Backup directory does not exist, no cleanup needed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during manual backup cleanup: $e');
      }
      throw Exception('Failed to cleanup old backups: $e');
    }
  }
}
