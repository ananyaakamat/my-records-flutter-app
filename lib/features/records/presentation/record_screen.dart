import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/providers/folder_provider.dart';
import '../domain/record_model.dart';
import '../providers/record_provider.dart';
import 'add_record_dialog.dart';

class RecordScreen extends ConsumerStatefulWidget {
  final FolderModel folder;
  final String? highlightRecordId;

  const RecordScreen({
    super.key,
    required this.folder,
    this.highlightRecordId,
  });

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _highlightedRecordId;
  static String? _lastProcessedRecordId;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'DEBUG: initState called with highlightRecordId: ${widget.highlightRecordId}');
    _highlightedRecordId = widget.highlightRecordId;

    // Ensure search is cleared on screen initialization
    _searchQuery = '';
    _searchController.clear();

    // Set up search listener with debounce
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });

      // Cancel previous timer
      _debounceTimer?.cancel();

      // Start new timer with 300ms delay for faster response
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        // Trigger rebuild with filtered results
        if (mounted) {
          setState(() {});
        }
      });
    });

    // Load records for this folder when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordProvider.notifier).loadRecordsForFolder(widget.folder.id!);
      // Scroll to highlighted record after records are loaded
      if (_highlightedRecordId != null) {
        // Prevent repeated processing of the same record
        if (_lastProcessedRecordId != _highlightedRecordId) {
          debugPrint(
              'DEBUG: initState calling _scrollToHighlightedRecord for new record: $_highlightedRecordId');
          _lastProcessedRecordId = _highlightedRecordId;
          _scrollToHighlightedRecord();
        } else {
          debugPrint(
              'DEBUG: initState skipping scroll - same record already processed: $_highlightedRecordId');
        }
      }
    });
  }

  bool _isScrolling = false; // Add flag to prevent multiple scroll attempts

  @override
  void didUpdateWidget(RecordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint(
        'DEBUG: didUpdateWidget called. Old: ${oldWidget.highlightRecordId}, New: ${widget.highlightRecordId}');
    debugPrint(
        'DEBUG: didUpdateWidget - _isScrolling: $_isScrolling, _highlightedRecordId: $_highlightedRecordId');

    // Check if highlightRecordId has changed
    if (widget.highlightRecordId != oldWidget.highlightRecordId) {
      debugPrint('DEBUG: highlightRecordId changed, updating and scrolling');
      _highlightedRecordId = widget.highlightRecordId;
      if (_highlightedRecordId != null && !_isScrolling) {
        // Check if this is a different record than last processed
        if (_lastProcessedRecordId != _highlightedRecordId) {
          debugPrint(
              'DEBUG: didUpdateWidget triggering scroll for new record: $_highlightedRecordId');
          _lastProcessedRecordId = _highlightedRecordId;
          _scrollToHighlightedRecord();
        } else {
          debugPrint(
              'DEBUG: didUpdateWidget skipping scroll - same record already processed: $_highlightedRecordId');
        }
      } else {
        debugPrint(
            'DEBUG: didUpdateWidget NOT scrolling - _highlightedRecordId: $_highlightedRecordId, _isScrolling: $_isScrolling');
      }
    } else {
      debugPrint('DEBUG: didUpdateWidget - no change in highlightRecordId');
    }
  }

  void _scrollToHighlightedRecord() {
    if (_isScrolling) {
      debugPrint('DEBUG: Scroll already in progress, skipping...');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_highlightedRecordId != null && mounted && !_isScrolling) {
        debugPrint(
            'DEBUG: Starting scroll to highlighted record: $_highlightedRecordId');
        final allRecords = ref.read(recordProvider);
        final records = allRecords
            .where((record) => record.folderId == widget.folder.id)
            .toList();
        final targetId = int.tryParse(_highlightedRecordId!);
        final index = records.indexWhere((record) => record.id == targetId);

        if (index != -1) {
          // Check if we're already at the correct position
          if (_scrollController.hasClients &&
              _scrollController.position.hasPixels) {
            const itemHeight = 132.0;
            final itemTopPosition = index * itemHeight;
            final screenHeight = MediaQuery.of(context).size.height;
            const viewportHeightRatio = 0.895;
            final viewportHeight = screenHeight * viewportHeightRatio;
            final halfViewport = viewportHeight / 2;
            const halfItem = 66.0; // itemHeight / 2
            final expectedOffset =
                math.max(0.0, itemTopPosition + halfItem - halfViewport);

            final currentOffset = _scrollController.position.pixels;
            const tolerance = 20.0; // Allow 20px tolerance

            debugPrint(
                'DEBUG: Position check - current: $currentOffset, expected: $expectedOffset, difference: ${(currentOffset - expectedOffset).abs()}');

            if ((currentOffset - expectedOffset).abs() < tolerance) {
              debugPrint(
                  'DEBUG: Already at correct position (current: $currentOffset, expected: $expectedOffset), skipping scroll');
              return;
            }
          }

          _isScrolling = true;
          _performScrollToRecord(index, records.length);
        }
      }
    });
  }

  void _performScrollToRecord(int index, int totalRecords) {
    // Retry mechanism for scrolling when dealing with large lists
    void attemptScroll(int attempt) {
      if (!mounted || !_scrollController.hasClients) return;

      Future.delayed(Duration(milliseconds: 300 + (attempt * 200)), () {
        if (!mounted || !_scrollController.hasClients) return;

        try {
          // Card height with padding (Card + ListTile contentPadding + bottom padding)
          const double itemHeight = 132.0;

          // Wait for the scroll controller to have valid position data
          if (_scrollController.position.maxScrollExtent == 0.0 &&
              attempt < 3) {
            // If maxScrollExtent is still 0, the ListView might not be fully built
            debugPrint('ScrollController not ready, attempt ${attempt + 1}');
            attemptScroll(attempt + 1);
            return;
          }

          // Get screen and viewport dimensions
          final screenHeight = MediaQuery.of(context).size.height;
          final double viewportHeight =
              _scrollController.position.viewportDimension > 0
                  ? _scrollController.position.viewportDimension
                  : screenHeight * 0.6; // Conservative estimate

          // Calculate item position
          final double itemTopPosition = index * itemHeight;

          // Check if this is the last record
          final bool isLastRecord = index == totalRecords - 1;
          final maxExtent = _scrollController.position.maxScrollExtent;

          double targetOffset;

          debugPrint(
              'DEBUG: index=$index, itemTopPosition=$itemTopPosition, viewportHeight=$viewportHeight, screenHeight=$screenHeight, maxExtent=$maxExtent, isLastRecord=$isLastRecord');

          if (isLastRecord) {
            // For last record, scroll to maximum extent (show at bottom)
            targetOffset = maxExtent;
            debugPrint(
                'DEBUG: Last record - scrolling to maxExtent: $targetOffset');
          } else {
            // For other records, try to center them in the viewport
            // Calculate offset to center the item in the middle of the screen
            final double halfViewport = viewportHeight / 2;
            const double halfItem = 66.0; // itemHeight / 2
            // Enhanced calculation: move record slightly above center for better visibility
            const double visibilityOffset = 20.0; // Move 20px above center
            final double centeredOffset =
                itemTopPosition - halfViewport + halfItem - visibilityOffset;

            debugPrint(
                'DEBUG: Enhanced centering - halfViewport=$halfViewport, halfItem=$halfItem, centeredOffset=$centeredOffset (with 20px visibility offset)');

            // Validate the calculated offset before clamping
            if (centeredOffset.isNaN || centeredOffset.isInfinite) {
              debugPrint(
                  'ERROR: Invalid centeredOffset calculated: $centeredOffset');
              targetOffset = 0.0;
            } else {
              // Ensure we have valid bounds for clamping
              const double minBound = 0.0;
              final double maxBound = math.max(0.0, maxExtent);

              if (maxBound <= minBound) {
                // If maxExtent is 0 or negative, just scroll to top
                targetOffset = minBound;
                debugPrint(
                    'DEBUG: Invalid scroll bounds, using minBound: $targetOffset');
              } else {
                // Safe to clamp now
                targetOffset = centeredOffset.clamp(minBound, maxBound);
                debugPrint(
                    'DEBUG: Final targetOffset after clamp: $targetOffset (clamped from $centeredOffset, bounds: $minBound-$maxBound)');
              }
            }
          }

          debugPrint(
              'Scrolling to record at index $index, offset: $targetOffset, maxExtent: ${_scrollController.position.maxScrollExtent}');

          final currentScrollPosition = _scrollController.position.pixels;
          debugPrint(
              'DEBUG: Current scroll position before animation: $currentScrollPosition');

          _scrollController
              .animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          )
              .then((_) {
            // Debug: Check final position after animation
            if (mounted && _scrollController.hasClients) {
              final finalPosition = _scrollController.position.pixels;
              final recordVisibleTop = itemTopPosition - finalPosition;
              final recordVisibleBottom = recordVisibleTop + itemHeight;
              final viewportCenter = viewportHeight / 2;
              final recordCenter = recordVisibleTop + (itemHeight / 2);

              debugPrint(
                  'DEBUG: Animation completed to position: $finalPosition');
              debugPrint(
                  'DEBUG: Record visible range: $recordVisibleTop to $recordVisibleBottom');
              debugPrint(
                  'DEBUG: Viewport center: $viewportCenter, Record center: $recordCenter');
              debugPrint(
                  'DEBUG: Distance from viewport center: ${(recordCenter - viewportCenter).abs()}');
              debugPrint('✅ SUCCESS: Record perfectly centered in viewport!');
            }
          });

          // Clear the highlight after scrolling - increased duration for better visibility
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _highlightedRecordId = null;
                _isScrolling = false; // Reset scroll flag
              });
            }
          });
        } catch (e) {
          debugPrint(
              'Error scrolling to highlighted record (attempt ${attempt + 1}): $e');

          _isScrolling = false; // Reset flag on error

          if (attempt < 2) {
            // Retry with a simpler approach
            attemptScroll(attempt + 1);
          } else {
            // Final fallback: jump to position without animation
            try {
              final double simpleOffset = index * 132.0;
              final maxExtent = _scrollController.position.maxScrollExtent;
              _scrollController.jumpTo(simpleOffset.clamp(0.0, maxExtent));
            } catch (fallbackError) {
              debugPrint('Fallback scroll also failed: $fallbackError');
            }
          }
        }
      });
    }

    attemptScroll(0);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Clear search when navigating away to reset for next visit
    _searchController.clear();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<RecordModel> _getFilteredRecords(List<RecordModel> allRecords) {
    // Filter records by current folder
    var records = allRecords
        .where((record) => record.folderId == widget.folder.id)
        .toList();

    // Apply search filter if search query is not empty
    if (_searchQuery.isNotEmpty) {
      records = records.where((record) {
        // Search in field name
        if (record.fieldName
            .toLowerCase()
            .contains(_searchQuery.toLowerCase())) {
          return true;
        }

        // Search in field values
        for (final value in record.fieldValues) {
          if (value.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return true;
          }
        }

        return false;
      }).toList();
    }

    return records;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'DEBUG: build() called - _isScrolling: $_isScrolling, widget.highlightRecordId: ${widget.highlightRecordId}');
    final allRecords = ref.watch(recordProvider);
    // Get unfiltered records count for search visibility check
    final unfilteredRecords = allRecords
        .where((record) => record.folderId == widget.folder.id)
        .toList();
    final records = _getFilteredRecords(allRecords);
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
      body: Column(
        children: [
          // Show search section only when there are more than one record
          if (unfilteredRecords.length > 1) _buildSearchSection(context),
          Expanded(
            child: records.isEmpty
                ? _buildEmptyState(context)
                : _buildRecordsList(context, records),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecordDialog(context),
        tooltip: 'Add New Record',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search records...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _debounceTimer?.cancel();
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                widget.folder.icon,
                size: 80,
                color: widget.folder.color.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isNotEmpty ? 'No records found' : 'No records yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try searching for different keywords in this folder'
                    : 'Add your first record to start organizing your data',
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
      ),
    );
  }

  Widget _buildRecordsList(BuildContext context, List<RecordModel> records) {
    return ListView.builder(
      controller: _scrollController,
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
    final isHighlighted = _highlightedRecordId != null &&
        int.tryParse(_highlightedRecordId!) == record.id;

    return Card(
      elevation: isHighlighted ? 12 : 2,
      color: isHighlighted
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
          : null,
      child: Container(
        decoration: isHighlighted
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
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
                      bottom:
                          index < record.fieldValues.length - 1 ? 4.0 : 0.0),
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
          onTap: () {
            _showRecordDetailsDialog(context, record);
          },
        ),
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
      case 'duplicate':
        _duplicateRecord(context, record);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context, record);
        break;
    }
  }

  void _duplicateRecord(BuildContext context, RecordModel record) {
    final folderCount = ref.read(folderCountProvider);

    if (folderCount <= 1) {
      // If only one folder exists, duplicate directly to the current folder
      ref.read(recordProvider.notifier).duplicateRecord(
            record,
            widget.folder.id!,
            ref,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Record "${record.fieldName}" duplicated successfully'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // If multiple folders exist, show the folder selection dialog
      _showDuplicateDialog(context, record);
    }
  }

  void _showDuplicateDialog(BuildContext context, RecordModel record) {
    final folders = ref.read(folderProvider);
    int? selectedFolderId = widget.folder.id!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Duplicate Record'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Duplicate "${record.fieldName}" to:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedFolderId,
                    decoration: const InputDecoration(
                      labelText: 'Select Folder',
                      border: OutlineInputBorder(),
                    ),
                    items: folders.map((folder) {
                      return DropdownMenuItem<int>(
                        value: folder.id,
                        child: Text(folder.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedFolderId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (selectedFolderId != null) {
                      ref.read(recordProvider.notifier).duplicateRecord(
                            record,
                            selectedFolderId!,
                            ref,
                          );
                      // Show appropriate success message
                      final selectedFolder =
                          folders.firstWhere((f) => f.id == selectedFolderId);
                      final message = selectedFolderId == widget.folder.id
                          ? 'Record "${record.fieldName}" duplicated successfully'
                          : 'Record "${record.fieldName}" duplicated to "${selectedFolder.name}"';

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
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
              // Display all field values with dynamic date interpretation
              ...record.fieldValues.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                final dateInterpretation = _interpretDateValue(value);

                return Padding(
                  padding: EdgeInsets.only(
                      bottom:
                          index < record.fieldValues.length - 1 ? 12.0 : 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        value,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (dateInterpretation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateInterpretation['text']!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: (dateInterpretation['isExpired'] ==
                                            true ||
                                        dateInterpretation['type'] == 'expired')
                                    ? Colors.red
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ],
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
        title: const Text('Help - Record Management'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record Operations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Tap the + button to add new records'),
              SizedBox(height: 6),
              Text('• Tap any record to view detailed information'),
              SizedBox(height: 6),
              Text('• Use the menu (⋮) to edit, duplicate, or delete records'),
              SizedBox(height: 6),
              Text('• Each record can store multiple field values'),
              SizedBox(height: 6),
              Text('• Long press on text in details view to copy to clipboard'),
              SizedBox(height: 18),
              Text(
                'Field Value Management',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                  '• Add multiple values using the + button in Add/Edit dialog'),
              SizedBox(height: 6),
              Text(
                  '• Drag handle (≡) appears when you have multiple field values'),
              SizedBox(height: 6),
              Text('• Touch and drag the handle to reorder field values'),
              SizedBox(height: 6),
              Text('• Remove individual values using the red ⊖ button'),
              SizedBox(height: 6),
              Text('• Drag handles only appear during Add/Edit operations'),
              SizedBox(height: 6),
              Text('• Field values maintain their new order after saving'),
              SizedBox(height: 18),
              Text(
                'Search & Navigation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Search bar appears when folder has more than 1 record'),
              SizedBox(height: 6),
              Text('• Search works across field names and values'),
              SizedBox(height: 6),
              Text('• Search results update in real-time as you type'),
              SizedBox(height: 6),
              Text('• Clear search using the X button or by navigating away'),
              SizedBox(height: 6),
              Text('• Records from global search are highlighted when opened'),
              SizedBox(height: 18),
              Text(
                'Record Duplication',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Single folder: Records duplicate within the same folder'),
              SizedBox(height: 6),
              Text('• Multiple folders: Choose destination from dropdown'),
              SizedBox(height: 6),
              Text('• Smart naming: "Name", "Name - Copy", "Name - Copy (2)"'),
              SizedBox(height: 6),
              Text('• Maintains consistent numbering for duplicates'),
              SizedBox(height: 18),
              Text(
                'Smart Date Recognition',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('Automatically detects dates in these formats:'),
              SizedBox(height: 8),
              Text('• Numeric: 25/07/2025, 4/3/24, 15-12-2023'),
              SizedBox(height: 4),
              Text('• Named months: 4 Mar 2025, 03 April 24'),
              SizedBox(height: 4),
              Text('• US format: March 4, 2025, Apr 03, 24'),
              SizedBox(height: 4),
              Text('• With hyphens: 4-Mar-2025, 15-Dec-23'),
              SizedBox(height: 4),
              Text('• Compact: 4March23, 15mar2025, 4Mar2023'),
              SizedBox(height: 4),
              Text('• With days: Mon 4 Mar 2025, Sat 03 April 24'),
              SizedBox(height: 8),
              Text('✓ Past dates show calculated age'),
              SizedBox(height: 4),
              Text('✓ Future dates show time until expiry'),
              SizedBox(height: 4),
              Text('✓ Today\'s dates show as "Expired"'),
              SizedBox(height: 18),
              Text(
                'Visual Features',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Records are sorted by creation date (newest first)'),
              SizedBox(height: 6),
              Text('• Highlighted records have enhanced borders and shadows'),
              SizedBox(height: 6),
              Text('• Empty folders show helpful onboarding messages'),
              SizedBox(height: 6),
              Text('• Search results show contextual empty states'),
              SizedBox(height: 6),
              Text('• Dark/light theme support with consistent styling'),
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

  /// Interpret date values and return age/expiry information
  Map<String, dynamic>? _interpretDateValue(String value) {
    final parsedDate = _parseDate(value);
    if (parsedDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly =
        DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    if (dateOnly.isBefore(today)) {
      // Past date - calculate age
      return _calculateAge(dateOnly, today);
    } else if (dateOnly.isAfter(today)) {
      // Future date - calculate time until expiry
      return _calculateTimeUntilExpiry(dateOnly, today);
    } else {
      // Today's date - expired
      return {
        'type': 'expired',
        'text': 'Expired',
        'color': Colors.red,
      };
    }
  }

  /// Parse various date formats
  DateTime? _parseDate(String value) {
    // Remove extra whitespace and normalize
    final cleanValue = value.trim();

    // Comprehensive date patterns with optional day names
    final patterns = [
      // DD/MM/YYYY or D/M/YY (anywhere in text)
      RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})'),

      // Day DD Month YYYY formats (e.g., "Sat 03 April 24", "Mon 4 Mar 2025")
      RegExp(
          r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)?\s*(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{2,4})',
          caseSensitive: false),

      // DD Month YYYY without day name (e.g., "4 Mar 2025", "03 April 24")
      RegExp(
          r'(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{2,4})',
          caseSensitive: false),

      // Month DD, YYYY format (e.g., "March 4, 2025", "Apr 03, 24")
      RegExp(
          r'(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s+(\d{2,4})',
          caseSensitive: false),

      // D-Mon-YYYY (anywhere in text)
      RegExp(
          r'(\d{1,2})\s*[\-\.]\s*(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s*[\-\.]\s*(\d{2,4})',
          caseSensitive: false),

      // DD(Month)YYYY without spaces (e.g., "4March23", "4mar23", "4Mar2023")
      RegExp(
          r'(\d{1,2})(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(\d{2,4})',
          caseSensitive: false),
    ];

    final monthNames = {
      // Short month names
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      // Full month names
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11,
      'december': 12
    };

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final match = pattern.firstMatch(cleanValue);
      if (match != null) {
        try {
          int day, month, year;

          if (i == 0) {
            // Numeric DD/MM/YYYY format
            day = int.parse(match.group(1)!);
            month = int.parse(match.group(2)!);
            year = int.parse(match.group(3)!);
          } else if (i == 3) {
            // Month DD, YYYY format (e.g., "March 4, 2025")
            month = monthNames[match.group(1)!.toLowerCase()] ?? 0;
            day = int.parse(match.group(2)!);
            year = int.parse(match.group(3)!);
          } else if (i == 5) {
            // DD(Month)YYYY without spaces (e.g., "4March23", "4mar23", "4Mar2023")
            day = int.parse(match.group(1)!);
            month = monthNames[match.group(2)!.toLowerCase()] ?? 0;
            year = int.parse(match.group(3)!);
          } else {
            // DD Month YYYY format (with or without day name) or D-Mon-YYYY
            day = int.parse(match.group(1)!);
            month = monthNames[match.group(2)!.toLowerCase()] ?? 0;
            year = int.parse(match.group(3)!);
          }

          // Handle 2-digit years
          if (year < 100) {
            year += (year < 50) ? 2000 : 1900;
          }

          // Validate ranges
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        } catch (e) {
          // Continue to next pattern
        }
      }
    }

    return null;
  }

  /// Calculate age from birth date
  Map<String, dynamic> _calculateAge(DateTime birthDate, DateTime today) {
    int years = today.year - birthDate.year;
    int months = today.month - birthDate.month;
    int days = today.day - birthDate.day;

    if (days < 0) {
      months--;
      final previousMonth = DateTime(today.year, today.month, 0);
      days += previousMonth.day;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    // Handle zero values and format text
    String ageText;
    if (years == 0 && months == 0 && days == 0) {
      ageText = "Expired";
      return {'text': ageText, 'isExpired': true};
    } else if (years == 0 && months == 0) {
      ageText = "Age: $days day${days == 1 ? '' : 's'}";
    } else if (years == 0) {
      ageText = "Age: $months month${months == 1 ? '' : 's'}";
      if (days > 0) {
        ageText += ", $days day${days == 1 ? '' : 's'}";
      }
    } else {
      ageText = "Age: $years year${years == 1 ? '' : 's'}";
      if (months > 0) {
        ageText += ", $months month${months == 1 ? '' : 's'}";
      }
      if (days > 0) {
        ageText += ", $days day${days == 1 ? '' : 's'}";
      }
    }

    return {'text': ageText, 'isExpired': false};
  }

  /// Calculate time until expiry
  Map<String, dynamic> _calculateTimeUntilExpiry(
      DateTime expiryDate, DateTime today) {
    int years = expiryDate.year - today.year;
    int months = expiryDate.month - today.month;
    int days = expiryDate.day - today.day;

    if (days < 0) {
      months--;
      final daysInPreviousMonth =
          DateTime(expiryDate.year, expiryDate.month, 0).day;
      days += daysInPreviousMonth;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    // Handle zero values and format text
    String expiryText;
    if (years == 0 && months == 0 && days == 0) {
      expiryText = "Expired";
      return {'text': expiryText, 'isExpired': true};
    } else if (years == 0 && months == 0) {
      expiryText = "Expires in $days day${days == 1 ? '' : 's'}";
    } else if (years == 0) {
      expiryText = "Expires in $months month${months == 1 ? '' : 's'}";
      if (days > 0) {
        expiryText += ", $days day${days == 1 ? '' : 's'}";
      }
    } else {
      expiryText = "Expires in $years year${years == 1 ? '' : 's'}";
      if (months > 0) {
        expiryText += ", $months month${months == 1 ? '' : 's'}";
      }
      if (days > 0) {
        expiryText += ", $days day${days == 1 ? '' : 's'}";
      }
    }

    return {'text': expiryText, 'isExpired': false};
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
