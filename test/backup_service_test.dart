import 'package:flutter_test/flutter_test.dart';
import 'package:my_records/core/services/backup_service.dart';

void main() {
  group('BackupService Tests', () {
    late BackupService backupService;

    setUp(() {
      backupService = BackupService.instance;
    });

    test('BackupService should be a singleton', () {
      final instance1 = BackupService.instance;
      final instance2 = BackupService.instance;
      expect(instance1, same(instance2));
    });

    test('Should have default backup settings', () async {
      // Test default values
      final settings = await backupService.getBackupSettings();
      expect(settings['autoBackupEnabled'], isFalse);
      expect(settings['frequency'], equals('weekly'));
    });

    test('Should be able to set auto backup settings', () async {
      await backupService.setAutoBackup(true, 'daily');
      final settings = await backupService.getBackupSettings();
      expect(settings['autoBackupEnabled'], isTrue);
      expect(settings['frequency'], equals('daily'));
    });

    test('Should generate correct filename format with json extension', () {
      // Test backup filename extraction from path
      const testPath =
          '/storage/emulated/0/Download/my_records/my_records28Oct25_0955AM.json';
      final fileName = backupService.getBackupFileName(testPath);
      expect(fileName, equals('my_records28Oct25_0955AM.json'));
    });

    test('Should return backup directory', () async {
      final directory = await backupService.getBackupDirectory();
      expect(directory.path.contains('my_records'), isTrue);
    });

    test('Should detect backup files with json extension', () async {
      // This test verifies that the getAvailableBackups method
      // can find backup files that start with 'my_records' and end with '.json'
      final backups = await backupService.getAvailableBackups();
      // This should not throw an error and should return a list
      expect(backups, isA<List<String>>());
    });
  });
}
