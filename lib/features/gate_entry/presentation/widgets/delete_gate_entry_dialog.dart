import 'package:flutter/material.dart';

/// Same bounds the server enforces (src/modules/gate/deletion.js).
const int kDeleteReasonMinLength = 5;
const int kDeleteReasonMaxLength = 500;

/// Asks an admin to confirm deleting [gateEntryNo] and to say why.
///
/// Returns the trimmed reason, or null when cancelled. The Delete button stays
/// disabled until the reason is long enough, so the server's 400 is only a
/// backstop.
Future<String?> showDeleteGateEntryDialog(
  BuildContext context, {
  required String gateEntryNo,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DeleteGateEntryDialog(gateEntryNo: gateEntryNo),
  );
}

class _DeleteGateEntryDialog extends StatefulWidget {
  const _DeleteGateEntryDialog({required this.gateEntryNo});

  final String gateEntryNo;

  @override
  State<_DeleteGateEntryDialog> createState() => _DeleteGateEntryDialogState();
}

class _DeleteGateEntryDialogState extends State<_DeleteGateEntryDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _valid => _reason.text.trim().length >= kDeleteReasonMinLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.delete_forever_outlined,
          color: theme.colorScheme.error, size: 32),
      title: const Text('Delete gate entry?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.gateEntryNo,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'The entry will be removed from the gate entry list, the '
              'dashboard, reconciliation and reports. Its invoice number can '
              'be entered again.\n\n'
              'A copy is kept under Deleted Entries with your name, the time '
              'and the reason below.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLines: 3,
              maxLength: kDeleteReasonMaxLength,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason for deleting *',
                hintText: 'e.g. Duplicate of an earlier entry',
                helperText: 'At least $kDeleteReasonMinLength characters',
                border: OutlineInputBorder(),
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
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _valid
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
      ],
    );
  }
}
