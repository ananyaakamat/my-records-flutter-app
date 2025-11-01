import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../folders/providers/folder_provider.dart';
import '../../folders/presentation/create_folder_dialog.dart';
import '../../folders/domain/folder_model.dart';
import '../../records/presentation/record_screen.dart';
import '../../security/presentation/change_pin_dialog.dart';
import 'backup_restore_screen.dart';

import '../../records/domain/record_model.dart';
import '../../../core/database/database_helper.dart';

class SearchResult {
  final RecordModel record;
  final FolderModel folder;
  final String matchedValue;

  SearchResult({
    required this.record,
    required this.folder,
    required this.matchedValue,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All Folders';
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });

      // Cancel previous timer
      _debounceTimer?.cancel();

      // Start new timer with 500ms delay
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _searchRecords();
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchRecords() async {
    if (_searchQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
      return;
    }

    final folders = ref.read(folderProvider);

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    final DatabaseHelper databaseHelper = DatabaseHelper();
    List<SearchResult> results = [];

    try {
      for (final folder in folders) {
        // Skip this folder if filter is set and doesn't match
        if (_selectedFilter != 'All Folders' &&
            folder.name != _selectedFilter) {
          continue;
        }

        // Get all records for this folder
        final List<Map<String, dynamic>> maps = await databaseHelper.query(
          'records',
          where: 'folder_id = ?',
          whereArgs: [folder.id],
        );

        final records = maps.map((map) => RecordModel.fromMap(map)).toList();

        // Search through each record's field name and field values
        for (final record in records) {
          String matchedValue = '';
          bool foundMatch = false;

          // Check field name
          if (record.fieldName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase())) {
            matchedValue = record.fieldName;
            foundMatch = true;
          }

          // Check field values
          if (!foundMatch) {
            for (final value in record.fieldValues) {
              if (value.toLowerCase().contains(_searchQuery.toLowerCase())) {
                matchedValue = value;
                foundMatch = true;
                break;
              }
            }
          }

          if (foundMatch) {
            results.add(SearchResult(
              record: record,
              folder: folder,
              matchedValue: matchedValue,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching records: $e');
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchResults = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: folders.isNotEmpty
                ? () => _showDeleteAllConfirmationDialog(context, ref)
                : null,
            tooltip: 'Delete All Folders',
            color: folders.isNotEmpty ? Colors.red.shade400 : null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context);
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Show search section only when there are more than one folder
          if (folders.length > 1) _buildSearchSection(context),
          Expanded(
            child: _buildMainContent(context, folders, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context, ref),
        tooltip: 'Create New Folder',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    final folders = ref.watch(folderProvider);
    final sortedFolderNames = folders.map((folder) => folder.name).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                          _isSearching = false;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          // Filter Dropdown
          Row(
            children: [
              Text(
                'Filter:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'All Folders',
                          child: Text('All Folders'),
                        ),
                        ...sortedFolderNames.map((folderName) {
                          return DropdownMenuItem<String>(
                            value: folderName,
                            child: Text(folderName),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedFilter = newValue;
                          });

                          // Cancel previous timer
                          _debounceTimer?.cancel();

                          // Start new timer with shorter delay for filter changes
                          _debounceTimer =
                              Timer(const Duration(milliseconds: 100), () {
                            _searchRecords();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      BuildContext context, List<FolderModel> folders, WidgetRef ref) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchQuery.isNotEmpty) {
      if (_searchResults.isEmpty) {
        return _buildNoResultsState(context);
      }
      return _buildSearchResults(context, ref);
    }

    if (folders.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    return _buildFolderList(context, folders, ref);
  }

  Widget _buildNoResultsState(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.3,
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'No records found',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching for different keywords or check other folders',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildSearchResultCard(context, result, ref),
        );
      },
    );
  }

  Widget _buildSearchResultCard(
      BuildContext context, SearchResult result, WidgetRef ref) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: result.folder.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            result.folder.icon,
            color: result.folder.color,
            size: 28,
          ),
        ),
        title: Text(
          result.record.fieldName,
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
            // Display field values
            ...result.record.fieldValues.map((value) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )),
            const SizedBox(height: 8),
            // Display folder name
            Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    result.folder.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RecordScreen(
                folder: result.folder,
                highlightRecordId: result.record.id?.toString(),
              ),
            ),
          );
        },
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view_folder') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RecordScreen(
                    folder: result.folder,
                    highlightRecordId: result.record.id?.toString(),
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'view_folder',
              child: ListTile(
                leading: Icon(Icons.folder_open),
                title: Text('View Folder'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.3,
        ),
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
          // Navigate to record screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RecordScreen(folder: folder),
            ),
          );
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

  void _showDeleteAllConfirmationDialog(BuildContext context, WidgetRef ref) {
    final folders = ref.read(folderProvider);
    final totalRecords =
        folders.fold(0, (sum, folder) => sum + folder.recordsCount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Delete All Folders',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text('• ${folders.length} folders'),
              const SizedBox(height: 4),
              Text('• $totalRecords records'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Warning',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This action cannot be undone. All your folders and their associated records will be permanently deleted.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await ref.read(folderProvider.notifier).deleteAllFolders();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                              'All folders and $totalRecords records deleted successfully'),
                        ],
                      ),
                      backgroundColor: Colors.green.shade600,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting folders: $e'),
                      backgroundColor: Colors.red.shade600,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help - Folder Management'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Folder Operations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Tap the + button to create new folders'),
              SizedBox(height: 6),
              Text('• Tap any folder to view its records'),
              SizedBox(height: 6),
              Text('• Use the menu (⋮) to edit, duplicate, or delete folders'),
              SizedBox(height: 6),
              Text('• Drag folders by the handle (☰) to reorder them'),
              SizedBox(height: 6),
              Text('• Each folder shows its record count and description'),
              SizedBox(height: 18),
              Text(
                'Global Search & Navigation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Search bar appears when you have 2+ folders'),
              SizedBox(height: 6),
              Text('• Search finds records across all folders instantly'),
              SizedBox(height: 6),
              Text('• Filter results by specific folders using dropdown'),
              SizedBox(height: 6),
              Text('• Tap search results to jump directly to that record'),
              SizedBox(height: 6),
              Text('• Records are highlighted when opened from search'),
              SizedBox(height: 6),
              Text('• Clear search anytime using the X button'),
              SizedBox(height: 18),
              Text(
                'Folder Customization',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Choose from various icons and colors when creating'),
              SizedBox(height: 6),
              Text('• Add optional descriptions for better organization'),
              SizedBox(height: 6),
              Text('• Edit existing folders to update name, icon, or color'),
              SizedBox(height: 6),
              Text('• Duplicate folders to quickly create similar ones'),
              SizedBox(height: 6),
              Text('• Custom sort order maintained through drag & drop'),
              SizedBox(height: 18),
              Text(
                'Bulk Management',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Delete All (🗑️) removes all folders and records'),
              SizedBox(height: 6),
              Text('• Confirmation dialog shows exact counts before deletion'),
              SizedBox(height: 6),
              Text('• Individual folder deletion preserves other data'),
              SizedBox(height: 6),
              Text('• Undo is not available - deletions are permanent'),
              SizedBox(height: 18),
              Text(
                'Settings & Security',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Toggle between light and dark themes instantly'),
              SizedBox(height: 6),
              Text('• Change PIN from Settings for enhanced security'),
              SizedBox(height: 6),
              Text('• Access Backup & Restore for data management'),
              SizedBox(height: 6),
              Text('• Automatic daily backups save to Downloads folder'),
              SizedBox(height: 6),
              Text('• PIN and biometric authentication protect your data'),
              SizedBox(height: 18),
              Text(
                'Visual Indicators',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Folder cards show custom icons and colors'),
              SizedBox(height: 6),
              Text('• Record counts update in real-time'),
              SizedBox(height: 6),
              Text('• Empty folders show helpful onboarding messages'),
              SizedBox(height: 6),
              Text('• Drag handles (☰) indicate reorderable items'),
              SizedBox(height: 6),
              Text('• Search results highlight matched content'),
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

  void _showChangePinHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help - Change PIN'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change PIN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('• PIN must be exactly 6 digits'),
              SizedBox(height: 8),
              Text('• You need to verify your current PIN first'),
              SizedBox(height: 8),
              Text('• Enter your new 6-digit PIN'),
              SizedBox(height: 8),
              Text('• Confirm your new PIN to complete the change'),
              SizedBox(height: 8),
              Text('• Your PIN secures access to all your records'),
              SizedBox(height: 8),
              Text('• Choose a PIN that is easy to remember but secure'),
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

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change PIN'),
              trailing: IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showChangePinHelpDialog(context),
                tooltip: 'Help',
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showChangePinDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup & Restore'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BackupRestoreScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ChangePinDialog(),
    );
  }
}
