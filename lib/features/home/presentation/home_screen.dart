import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../folders/providers/folder_provider.dart';
import '../../folders/presentation/create_folder_dialog.dart';
import '../../folders/domain/folder_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderProvider);
    final folderCount = ref.watch(folderCountProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Folder Lists',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$folderCount folders',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              ref.read(themeProvider.notifier).state =
                  isDarkMode ? ThemeMode.light : ThemeMode.dark;
            },
            tooltip:
                isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog(context);
            },
            tooltip: 'Help',
          ),
        ],
      ),
      body: folders.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildFolderList(context, folders, ref),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context, ref),
        tooltip: 'Create New Folder',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'No folders yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first folder to organize your records',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCreateFolderDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Folder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderList(
      BuildContext context, List<FolderModel> folders, WidgetRef ref) {
    // Sort folders by sortOrder
    final sortedFolders = List<FolderModel>.from(folders)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedFolders.length,
      onReorder: (oldIndex, newIndex) {
        _handleReorder(oldIndex, newIndex, sortedFolders, ref);
      },
      itemBuilder: (context, index) {
        final folder = sortedFolders[index];
        return Padding(
          key: ValueKey(folder.id),
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildFolderCard(context, folder, ref),
        );
      },
    );
  }

  Widget _buildFolderCard(
      BuildContext context, FolderModel folder, WidgetRef ref) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: folder.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            folder.icon,
            color: folder.color,
            size: 28,
          ),
        ),
        title: Text(
          folder.name,
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
            if (folder.description != null &&
                folder.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                folder.description!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${folder.recordsCount} records',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: SizedBox(
            width: 80, // Fixed width to prevent overflow
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Drag handle
                Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 4), // Reduced spacing
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _handleFolderAction(context, value, folder, ref),
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
                      value: 'duplicate',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_copy, size: 18),
                          SizedBox(width: 8),
                          Text('Duplicate'),
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
              ],
            )),
        onTap: () {
          // Navigate to folder contents
          _showFolderDetailsDialog(context, folder);
        },
      ),
    );
  }

  void _handleReorder(
      int oldIndex, int newIndex, List<FolderModel> folders, WidgetRef ref) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Create a copy of the list
    final updatedFolders = List<FolderModel>.from(folders);
    final item = updatedFolders.removeAt(oldIndex);
    updatedFolders.insert(newIndex, item);

    // Update sort orders
    for (int i = 0; i < updatedFolders.length; i++) {
      final updatedFolder = updatedFolders[i].copyWith(sortOrder: i);
      ref.read(folderProvider.notifier).updateFolder(updatedFolder);
    }
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
  }

  void _handleFolderAction(
      BuildContext context, String action, FolderModel folder, WidgetRef ref) {
    switch (action) {
      case 'edit':
        showDialog(
          context: context,
          builder: (context) => CreateFolderDialog(folderToEdit: folder),
        );
        break;
      case 'duplicate':
        ref.read(folderProvider.notifier).duplicateFolder(folder);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder "${folder.name}" duplicated successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context, folder, ref);
        break;
    }
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, FolderModel folder, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: SingleChildScrollView(
          child: Text(
              'Are you sure you want to delete "${folder.name}"? This action cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(folderProvider.notifier).deleteFolder(folder.id!);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Folder "${folder.name}" deleted successfully'),
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

  void _showFolderDetailsDialog(BuildContext context, FolderModel folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(folder.icon, color: folder.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                folder.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (folder.description != null &&
                  folder.description!.isNotEmpty) ...[
                Text('Description: ${folder.description}'),
                const SizedBox(height: 8),
              ],
              Text('Records: ${folder.recordsCount}'),
              const SizedBox(height: 8),
              Text('Created: ${_formatDateTime(folder.createdAt)}'),
              const SizedBox(height: 8),
              Text('Last Updated: ${_formatDateTime(folder.updatedAt)}'),
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
              // TODO: Navigate to folder contents
            },
            child: const Text('Open Folder'),
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
                'My Records - Folder Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('• Tap the + button to create new folders'),
              SizedBox(height: 8),
              Text('• Tap on a folder to view its contents'),
              SizedBox(height: 8),
              Text('• Use the menu (⋮) to edit, duplicate, or delete folders'),
              SizedBox(height: 8),
              Text(
                  '• Toggle between light and dark themes using the theme button'),
              SizedBox(height: 8),
              Text(
                  '• Organize your documents, certificates, and records in folders'),
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
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
