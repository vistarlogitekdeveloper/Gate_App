import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/user_role.dart';
import '../data/gate_entry_repository_impl.dart';
import '../domain/models/gate_entry_query.dart';
import '../domain/services/dc_qr.dart';
import 'gate_entry_detail_page.dart';
import 'widgets/e_invoice_qr_scanner_page.dart';

/// Who may scan a delivery challan at the gate: whoever may record Gate Out.
bool canScanDc(UserRole? role) =>
    role == UserRole.gateSecurity ||
    role == UserRole.warehouseExecutive ||
    (role?.isAdminOrWarehouseManager ?? false);

void _say(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? Colors.red.shade700 : null,
  ));
}

/// Scan the QR on a QR Dispatch delivery challan (or type its number) and open
/// the Gate Out entry Finish loading made for it. A different vehicle on the
/// challan than on the entry is shown before the entry opens.
Future<void> scanDcAndOpen(BuildContext context, WidgetRef ref) async {
  final raw = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => const EInvoiceQrScannerPage(title: 'Scan delivery challan', typeHint: 'DC2026000007'),
  ));
  if (raw == null || !context.mounted) return;
  final dc = parseDcQr(raw);
  if (dc == null) {
    _say(context, 'That is not a delivery challan QR.', error: true);
    return;
  }
  final res = await ref.read(gateEntryRepositoryProvider).getGateEntries(query: GateEntryQuery(q: dc.dcNo));
  if (!context.mounted) return;
  if (!res.success) {
    _say(context, res.message.isNotEmpty ? res.message : 'Could not look up ${dc.dcNo}.', error: true);
    return;
  }
  final entry = pickOutEntry(res.data?.items ?? const [], dc.dcNo);
  if (entry == null) {
    _say(context, 'No Gate Out entry for ${dc.dcNo}. Has the vehicle finished loading in QR Dispatch?', error: true);
    return;
  }
  if (vehicleMismatch(dc.vehicleNo, entry.vehicleNo)) {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('Different vehicle'),
        content: Text('The challan ${dc.dcNo} names ${dc.vehicleNo}, but its gate entry is for ${entry.vehicleNo}.\n\n'
            'Check the lorry before letting it out.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Stop')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Open anyway')),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GateEntryDetailPage(entryId: entry.id)));
}
