import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/record_model.dart';
import '../providers/record_provider.dart';

class AddRecordDialog extends ConsumerStatefulWidget {
  final int folderId;
  final RecordModel? recordToEdit;

  const AddRecordDialog({
    super.key,
    required this.folderId,
    this.recordToEdit,
  });

  @override
  ConsumerState<AddRecordDialog> createState() => _AddRecordDialogState();
}

class _AddRecordDialogState extends ConsumerState<AddRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fieldNameController = TextEditingController();
  final List<TextEditingController> _fieldValueControllers = [];

  @override
  void initState() {
    super.initState();
    if (widget.recordToEdit != null) {
      _fieldNameController.text = widget.recordToEdit!.fieldName;
      // For editing, load all existing field values
      for (final value in widget.recordToEdit!.fieldValues) {
        _fieldValueControllers.add(TextEditingController(text: value));
      }
      // Ensure at least one controller exists
      if (_fieldValueControllers.isEmpty) {
        _fieldValueControllers.add(TextEditingController());
      }
    } else {
      // For new records, start with one empty field value controller
      _fieldValueControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _fieldNameController.dispose();
    for (final controller in _fieldValueControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Helper method to capitalize the first letter of a string
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Add a new field value input
  void _addFieldValue() {
    setState(() {
      _fieldValueControllers.add(TextEditingController());
    });
  }

  /// Remove a field value input at the specified index
  void _removeFieldValue(int index) {
    if (_fieldValueControllers.length > 1) {
      setState(() {
        _fieldValueControllers[index].dispose();
        _fieldValueControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.recordToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(
                        isEditing ? Icons.edit : Icons.add,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Record' : 'Add New Record',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Field Name Input
                  TextFormField(
                    controller: _fieldNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Field Name',
                      hintText: 'e.g., Phone Number, Address, Notes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a field name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Field Values Section
                  Row(
                    children: [
                      Text(
                        'Field Values',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _addFieldValue,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add another field value',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Field Value Inputs
                  ...List.generate(_fieldValueControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fieldValueControllers[index],
                              decoration: InputDecoration(
                                labelText: _fieldValueControllers.length > 1
                                    ? 'Field Value ${index + 1}'
                                    : 'Field Value',
                                hintText: 'Enter the value for this field',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.edit),
                              ),
                              maxLines: 3,
                              minLines: 1,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a field value';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_fieldValueControllers.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeFieldValue(index),
                              icon: const Icon(Icons.remove_circle),
                              color: Colors.red,
                              tooltip: 'Remove this field value',
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Help Text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Create custom field-value pairs to store any information you need.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _saveRecord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: Text(isEditing ? 'Update' : 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveRecord() {
    if (_formKey.currentState?.validate() ?? false) {
      final capitalizedFieldName =
          _capitalizeFirstLetter(_fieldNameController.text.trim());

      // Collect all non-empty field values
      final List<String> validFieldValues = _fieldValueControllers
          .map((controller) => _capitalizeFirstLetter(controller.text.trim()))
          .where((value) => value.isNotEmpty)
          .toList();

      if (validFieldValues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter at least one field value')),
        );
        return;
      }

      if (widget.recordToEdit != null) {
        // For editing, update the existing record with all field values
        final record = RecordModel(
          id: widget.recordToEdit!.id,
          folderId: widget.folderId,
          fieldName: capitalizedFieldName,
          fieldValues: validFieldValues,
          createdAt: widget.recordToEdit!.createdAt,
          updatedAt: DateTime.now(),
        );

        ref.read(recordProvider.notifier).updateRecord(record, ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Record "${record.fieldName}" updated successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // For new records, create single record with all field values
        final record = RecordModel(
          folderId: widget.folderId,
          fieldName: capitalizedFieldName,
          fieldValues: validFieldValues,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        ref.read(recordProvider.notifier).addRecord(record, ref);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Record "$capitalizedFieldName" created successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      Navigator.of(context).pop();
    }
  }
}
