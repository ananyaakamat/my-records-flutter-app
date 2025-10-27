import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../folders/domain/folder_model.dart';
import '../domain/record_model.dart';
import '../providers/record_provider.dart';
import 'add_record_dialog.dart';

class RecordScreen extends ConsumerStatefulWidget {
  final FolderModel folder;

  const RecordScreen({super.key, required this.folder});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  @override
  void initState() {
    super.initState();
    // Load records for this folder when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordProvider.notifier).loadRecordsForFolder(widget.folder.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.folder.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${records.length} records',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog(context);
            },
            tooltip: 'Help',
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              ref.read(themeProvider.notifier).state =
                  isDarkMode ? ThemeMode.light : ThemeMode.dark;
            },
            tooltip:
                isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: records.isEmpty
          ? _buildEmptyState(context)
          : _buildRecordsList(context, records),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecordDialog(context),
        tooltip: 'Add New Record',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.folder.icon,
              size: 80,
              color: widget.folder.color.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No records yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first record to start organizing your data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddRecordDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Record'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList(BuildContext context, List<RecordModel> records) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildRecordCard(context, record),
        );
      },
    );
  }

  Widget _buildRecordCard(BuildContext context, RecordModel record) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.folder.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.description,
            color: widget.folder.color,
            size: 28,
          ),
        ),
        title: Text(
          record.fieldName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Display all field values
            ...record.fieldValues.asMap().entries.map((entry) {
              final index = entry.key;
              final value = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index < record.fieldValues.length - 1 ? 4.0 : 0.0),
                child: Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              _formatDateTime(record.createdAt),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleRecordAction(context, value, record),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          _showRecordDetailsDialog(context, record);
        },
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddRecordDialog(folderId: widget.folder.id!),
    );
  }

  void _handleRecordAction(
      BuildContext context, String action, RecordModel record) {
    switch (action) {
      case 'edit':
        showDialog(
          context: context,
          builder: (context) => AddRecordDialog(
            folderId: widget.folder.id!,
            recordToEdit: record,
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context, record);
        break;
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, RecordModel record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: SingleChildScrollView(
          child: Text(
              'Are you sure you want to delete "${record.fieldName}"? This action cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(recordProvider.notifier).deleteRecord(
                    record.id!,
                    widget.folder.id!,
                    ref,
                  );
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Record "${record.fieldName}" deleted successfully'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRecordDetailsDialog(BuildContext context, RecordModel record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          record.fieldName,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.fieldValues.length > 1 ? 'Values:' : 'Value:',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              // Display all field values
              ...record.fieldValues.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom:
                          index < record.fieldValues.length - 1 ? 12.0 : 0.0),
                  child: SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text('Created: ${_formatDateTime(record.createdAt)}'),
              const SizedBox(height: 4),
              Text('Updated: ${_formatDateTime(record.updatedAt)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => AddRecordDialog(
                  folderId: widget.folder.id!,
                  recordToEdit: record,
                ),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Records - Record Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('• Tap the + button to create new records'),
              SizedBox(height: 8),
              Text('• Tap on a record card to view full details'),
              SizedBox(height: 8),
              Text('• Use the menu (⋮) to edit or delete records'),
              SizedBox(height: 8),
              Text('• Records are sorted alphabetically by field name'),
              SizedBox(height: 8),
              Text('• Each record can have multiple field values'),
              SizedBox(height: 8),
              Text('• Long press on text to copy to clipboard'),
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

  String _formatDateTime(DateTime dateTime) {
    final months = [
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

    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '${dateTime.day} ${months[dateTime.month]} ${dateTime.year}, $displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}
