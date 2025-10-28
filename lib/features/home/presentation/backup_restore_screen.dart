import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/services/backup_service.dart';
import '../../folders/providers/folder_provider.dart';

class BackupInfo {
  final String id;
  final String displayName;
  final DateTime createdTime;
  final int size;

  BackupInfo({
    required this.id,
    required this.displayName,
    required this.createdTime,
    required this.size,
  });
}

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final BackupService _backupService = BackupService.instance;
  bool _isLoading = false;
  bool _autoBackupEnabled = false;
  String _autoBackupFrequency = 'daily';
  String? _lastBackupInfo;
  List<BackupInfo> _availableBackups = [];
  bool _backupsLoaded = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeBackupService();
    _loadSettings();
    _loadBackupInfo();
    _loadAvailableBackups();

    // Start timer to refresh backup info every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadBackupInfo();
    });
  }

  Future<void> _initializeBackupService() async {
    try {
      await _backupService.initialize();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize backup service: $e');
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _backupService.getBackupSettings();
      setState(() {
        _autoBackupEnabled = settings['auto_backup_enabled'] ?? false;
        _autoBackupFrequency = settings['auto_backup_frequency'] ?? 'daily';
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load backup settings: $e');
      }
      setState(() {
        _autoBackupEnabled = false;
        _autoBackupFrequency = 'daily';
      });
    }
  }

  Future<void> _loadBackupInfo() async {
    try {
      final lastBackupInfo = await _backupService.getLastBackupInfo();
      if (mounted) {
        setState(() {
          _lastBackupInfo = lastBackupInfo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastBackupInfo = 'No backup created yet';
        });
      }
    }
  }

  Future<void> _loadAvailableBackups() async {
    if (_backupsLoaded) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final backupPaths = await _backupService.getAvailableBackups();
      List<BackupInfo> backups = [];

      for (String path in backupPaths) {
        final file = File(path);
        if (await file.exists()) {
          final stat = await file.stat();
          final fileName = file.path.split('/').last.split('\\').last;
          backups.add(BackupInfo(
            id: fileName,
            displayName: fileName,
            createdTime: stat.modified,
            size: stat.size,
          ));
        }
      }

      // Sort by creation time (newest first)
      backups.sort((a, b) => b.createdTime.compareTo(a.createdTime));

      setState(() {
        _availableBackups = backups;
        _backupsLoaded = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load backups: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    // Check if folders exist before attempting backup
    final hasFolders = await _backupService.hasFoldersToBackup();
    if (!hasFolders) {
      _showErrorDialog(
          'No folders found!\n\nPlease create some folders with records before creating a backup. A backup can only be created when you have existing data to back up.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final filePath = await _backupService.createBackup();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showBackupSuccessDialog(filePath);
        await _loadBackupInfo();
        await _refreshBackups();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show user-friendly error message
        String errorMessage = 'Backup failed: ';
        if (e.toString().contains('No folders found')) {
          errorMessage =
              'No folders found! Please create some folders with records first.';
        } else {
          errorMessage += e
              .toString()
              .replaceAll('Exception: Failed to create backup: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showBackupSuccessDialog(String filePath) async {
    // Get backup statistics
    final stats = await _backupService.getBackupStats();
    final fileName = _backupService.getBackupFileName(filePath);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Backup Created Successfully!',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup file: $fileName',
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text('📁 Folders backed up: ${stats['folders']}'),
            const SizedBox(height: 4),
            Text('📄 Records backed up: ${stats['records']}'),
            const SizedBox(height: 12),
            const Text(
              'Your backup contains all folders and their respective records. Use this file to restore your data if needed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await _backupService.shareBackup(filePath);
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to share backup: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshBackups() async {
    setState(() {
      _backupsLoaded = false;
      _availableBackups.clear();
    });
    await _loadAvailableBackups();
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    final confirmed = await _showConfirmDialog(
      'Restore Backup',
      'This will replace all current data with the backup data. This action cannot be undone.\n\nAre you sure you want to continue?',
    );

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final backupPaths = await _backupService.getAvailableBackups();
      final backupPath =
          backupPaths.firstWhere((path) => path.contains(backup.id));

      await _backupService.restoreFromBackup(backupPath);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Refresh the folder provider to show restored data
        ref.invalidate(folderProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showErrorDialog('Failed to restore backup: $e');
      }
    }
  }

  Future<void> _shareBackup(BackupInfo backup) async {
    try {
      final backupPaths = await _backupService.getAvailableBackups();
      final backupPath =
          backupPaths.firstWhere((path) => path.contains(backup.id));
      final backupFile = File(backupPath);

      if (!await backupFile.exists()) {
        _showErrorDialog('Backup file not found');
        return;
      }

      final result = await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'My Records Backup - ${backup.displayName}\n\n'
            'Created: ${backup.createdTime.day}/${backup.createdTime.month}/${backup.createdTime.year}\n'
            'Size: ${(backup.size / 1024).toStringAsFixed(1)} KB',
        subject: 'My Records Backup - ${backup.displayName}',
      );

      if (result.status == ShareResultStatus.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Backup shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to share backup: $e');
    }
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    final confirmed = await _showConfirmDialog(
      'Delete Backup',
      'Are you sure you want to delete this backup? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      final backupPaths = await _backupService.getAvailableBackups();
      final backupPath =
          backupPaths.firstWhere((path) => path.contains(backup.id));
      final backupFile = File(backupPath);

      if (await backupFile.exists()) {
        await backupFile.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _refreshBackups();
      } else {
        _showErrorDialog('Backup file not found');
      }
    } catch (e) {
      _showErrorDialog('Failed to delete backup: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _backupService.setAutoBackup(
          _autoBackupEnabled, _autoBackupFrequency);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _autoBackupEnabled
                      ? 'Auto backup enabled ($_autoBackupFrequency)!'
                      : 'Auto backup disabled!',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to save settings: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: title.contains('Delete')
                ? const Text('Delete')
                : const Text('Restore'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).pop(),
          color: Colors.white,
        ),
        title: const Text(
          'Backup & Restore',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
            color: Colors.white,
            tooltip: 'Help',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickActionsCard(),
            const SizedBox(height: 12),
            _buildBackupInfoCard(),
            const SizedBox(height: 12),
            _buildAutoBackupCard(),
            const SizedBox(height: 12),
            _buildAvailableBackupsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('Create Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _refreshBackups,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackupInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Backup Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade600.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time,
                        color: Colors.blue.shade300, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Backup',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade200,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _lastBackupInfo ?? 'Loading...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.policy, color: Colors.green.shade300, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Retention Policy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade200,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Automatically keeps the last 3 backups and removes older ones',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoBackupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Auto Backup Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Auto Backup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Automatically create backups',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _autoBackupEnabled,
                onChanged: (value) {
                  setState(() {
                    _autoBackupEnabled = value;
                  });
                },
                activeColor: Colors.teal.shade400,
              ),
            ],
          ),
          if (_autoBackupEnabled) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Backup Frequency',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                DropdownButton<String>(
                  value: _autoBackupFrequency,
                  dropdownColor: Colors.grey.shade800,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _autoBackupFrequency = value;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Daily'),
                    ),
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Weekly'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${_autoBackupFrequency == 'daily' ? 'Daily' : 'Weekly'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableBackupsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_outlined, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Available Backups',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_availableBackups.isEmpty && !_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No backups found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade300,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create your first backup to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableBackups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final backup = _availableBackups[index];
                return _buildBackupItem(backup);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBackupItem(BackupInfo backup) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.teal,
                radius: 18,
                child: Icon(
                  Icons.backup,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backup.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(backup.size / 1024).toStringAsFixed(1)} KB • ${formatter.format(backup.createdTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionIcon(
                Icons.restore,
                Colors.green.shade600,
                () => _restoreBackup(backup),
              ),
              const SizedBox(width: 20),
              _buildActionIcon(
                Icons.share,
                Colors.blue.shade600,
                () => _shareBackup(backup),
              ),
              const SizedBox(width: 20),
              _buildActionIcon(
                Icons.delete,
                Colors.red.shade600,
                () => _deleteBackup(backup),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: _isLoading ? Colors.grey : color,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help - Backup & Restore'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Backup & Restore',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Automatic Backup:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Automatic backups run daily by default'),
              SizedBox(height: 4),
              Text('• Change frequency to Weekly if preferred'),
              SizedBox(height: 4),
              Text(
                  '• Backups saved to Downloads/my_records folder as .json files'),
              SizedBox(height: 4),
              Text(
                  '• Runs automatically in the background without device constraints'),
              SizedBox(height: 4),
              Text('• Automatically keeps only 3 most recent backups'),
              SizedBox(height: 16),
              Text(
                'Manual Backup:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Tap "Create Backup" to manually backup your data'),
              SizedBox(height: 4),
              Text(
                  '• Requires at least one existing folder to create a backup'),
              SizedBox(height: 4),
              Text('• Exports all your folders and their respective records'),
              SizedBox(height: 4),
              Text('• Option to share backup file after creation'),
              SizedBox(height: 16),
              Text(
                'Restore from Backup:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Select any .json backup file from your device'),
              SizedBox(height: 4),
              Text('• Automatically detects My Records backup files'),
              SizedBox(height: 4),
              Text('• Replaces all current data with backup data'),
              SizedBox(height: 4),
              Text('• This action cannot be undone'),
              SizedBox(height: 4),
              Text('• Recommended to create backup before restore'),
              SizedBox(height: 16),
              Text(
                'Settings:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Toggle automatic backup on/off'),
              SizedBox(height: 4),
              Text('• Choose between Daily or Weekly frequency'),
              SizedBox(height: 4),
              Text('• View when the last backup was performed'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
