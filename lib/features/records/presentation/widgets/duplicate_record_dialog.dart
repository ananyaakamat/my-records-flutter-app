import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../folders/domain/folder_model.dart';
import '../../../folders/providers/folder_provider.dart';
import '../../domain/record_model.dart';
import '../../providers/record_provider.dart';

class DuplicateRecordDialog extends ConsumerStatefulWidget {
  final RecordModel record;
  final int currentFolderId;

  const DuplicateRecordDialog({
    super.key,
    required this.record,
    required this.currentFolderId,
  });

  @override
  ConsumerState<DuplicateRecordDialog> createState() =>
      _DuplicateRecordDialogState();
}

class _DuplicateRecordDialogState extends ConsumerState<DuplicateRecordDialog> {
  int? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
    debugPrint(
        'DEBUG: DuplicateRecordDialog initialized with folderId: ${widget.currentFolderId}');
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(folderProvider);
    debugPrint('DEBUG: Dialog build - total folders: ${folders.length}');

    // Sort folders alphabetically by name
    final sortedFolders = List<FolderModel>.from(folders);
    sortedFolders
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return AlertDialog(
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      title: const Row(
        children: [
          Icon(Icons.content_copy, size: 24, color: Colors.blue),
          SizedBox(width: 8),
          Text('Duplicate Record',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duplicate "${widget.record.fieldName}" to:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedFolderId,
            decoration: const InputDecoration(
              labelText: 'Select Folder',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.folder),
            ),
            items: sortedFolders.map((folder) {
              return DropdownMenuItem<int>(
                value: folder.id,
                child: Row(
                  children: [
                    Icon(
                      folder.icon,
                      color: folder.color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        folder.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (folder.id == widget.currentFolderId)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedFolderId = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedFolderId == null
              ? null
              : () {
                  final selectedFolderId = _selectedFolderId!;
                  Navigator.of(context).pop();
                  _duplicateRecord(selectedFolderId, context);
                },
          child: const Text('OK'),
        ),
      ],
    );
  }

  void _duplicateRecord(int selectedFolderId, BuildContext context) {
    ref.read(recordProvider.notifier).duplicateRecord(
          widget.record,
          selectedFolderId,
          ref,
        );

    final selectedFolder = ref
        .read(folderProvider)
        .firstWhere((folder) => folder.id == selectedFolderId);

    final message = selectedFolderId == widget.currentFolderId
        ? 'Record "${widget.record.fieldName}" duplicated successfully'
        : 'Record "${widget.record.fieldName}" duplicated to "${selectedFolder.name}"';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
