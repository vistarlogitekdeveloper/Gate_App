import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/ui/widgets/progress_dialog.dart';
import '../data/gate_entry_repository_impl.dart';
import 'controllers/gate_entry_controller.dart';

// Gate out is per count sheet: one count sheet is one vehicle, so when it
// leaves, every invoice saved on it is gated out together -- from the
// dashboard, the gate entry's page and the Count Sheets screens alike.

/// Who may record a gate out (the server allows the same roles).
bool canRecordGateOut(WidgetRef ref) {
  final session = ref.read(sessionControllerProvider);
  if (session is! Authenticated) return false;
  final role = session.role;
  return role == UserRole.gateSecurity ||
      role == UserRole.warehouseExecutive ||
      role.isAdminOrWarehouseManager;
}

String _duration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

/// Asks for confirmation (with optional remarks), then gates out the vehicle
/// of [countSheetNo]. Shows the result; true when it was recorded.
///
/// [invoiceCount] / [vendors] / [minutesInside] are shown when known, so the
/// guard sees what is about to be gated out.
Future<bool> confirmAndGateOutCountSheet(
  BuildContext context,
  WidgetRef ref, {
  required String countSheetNo,
  String? vehicleNo,
  int? invoiceCount,
  String? vendors,
  int? minutesInside,
}) async {
  const red = Color(0xFFD32F2F);
  const unloadingThresholdMinutes = 120;
  final vehicle =
      (vehicleNo ?? '').trim().isEmpty ? 'the vehicle' : vehicleNo!.trim();
  final remarksController = TextEditingController();
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
      return AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: red, size: 32),
        title: Text('Gate Out ${vehicleNo?.trim().isNotEmpty == true ? vehicleNo!.trim() : 'vehicle'}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.fact_check_outlined,
                        color: Theme.of(ctx).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Count Sheet $countSheetNo'
                        '${invoiceCount != null ? '  ·  $invoiceCount invoice${invoiceCount == 1 ? '' : 's'}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              if ((vendors ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(vendors!.trim(), style: TextStyle(color: muted)),
              ],
              const SizedBox(height: 10),
              Text(
                'Every invoice of this count sheet is gated out together. '
                'Record it only once $vehicle has actually left the gate.',
              ),
              if (minutesInside != null && minutesInside > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Vehicle has been inside for ${_duration(minutesInside)}.',
                  style: TextStyle(
                    color: minutesInside >= unloadingThresholdMinutes
                        ? red
                        : muted,
                    fontWeight: minutesInside >= unloadingThresholdMinutes
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                if (minutesInside >= unloadingThresholdMinutes)
                  Text(
                    'If it is leaving without unloading, say so in the remarks.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional)',
                  hintText: 'e.g. Vehicle exited after unloading',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: red),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Confirm Gate Out'),
          ),
        ],
      );
    },
  );
  final remarks = remarksController.text.trim();
  remarksController.dispose();
  if (proceed != true || !context.mounted) return false;

  final response = await runWithProgressDialog(
    context,
    () => ref
        .read(gateEntryRepositoryProvider)
        .gateOutCountSheet(countSheetNo, remarks: remarks),
    label: 'Recording gate out...',
  );
  if (response.success) {
    // Best effort: the gate entry list picks up the new gate out times.
    ref
        .read(gateEntryControllerProvider.notifier)
        .fetchEntries(refresh: true)
        .catchError((_) {});
  }
  if (!context.mounted) return response.success;
  final n = response.data ?? 0;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: response.success ? Colors.green : Colors.redAccent,
    content: Text(response.success
        ? 'Gate out recorded for $vehicle · Count Sheet $countSheetNo'
            '${n > 1 ? ' ($n invoices)' : ''}'
        : (response.message.isNotEmpty
            ? response.message
            : 'Gate out failed for Count Sheet $countSheetNo')),
  ));
  return response.success;
}
