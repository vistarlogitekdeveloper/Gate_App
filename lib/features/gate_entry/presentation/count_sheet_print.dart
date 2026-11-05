import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/ui/widgets/progress_dialog.dart';
import '../data/gate_entry_repository_impl.dart';
import '../domain/models/gate_entry.dart';
import '../domain/services/count_sheet_pdf_service.dart';

// Viewing and printing a count sheet (the Receipt and Put Away Sheet), from
// the Count Sheets screens and right after a gate entry is saved.

String _fileName(String countSheetNo) => 'Count-Sheet-$countSheetNo.pdf';

/// The sheet's PDF. Uses [entries] when the caller already has them,
/// otherwise loads every gate entry on the count sheet.
Future<Uint8List> _buildPdf(
  WidgetRef ref,
  String countSheetNo, {
  List<GateEntry>? entries,
}) async {
  var lines = entries;
  if (lines == null) {
    final response = await ref
        .read(gateEntryRepositoryProvider)
        .getCountSheetEntries(countSheetNo);
    if (!response.success || response.data == null) {
      throw Exception(response.message.isNotEmpty
          ? response.message
          : 'Could not load count sheet $countSheetNo.');
    }
    lines = response.data!;
  }
  if (lines.isEmpty) {
    throw Exception('Count sheet $countSheetNo has no gate entries.');
  }
  final session = ref.read(sessionControllerProvider);
  final auth = session is Authenticated ? session : null;
  return CountSheetPdfService.build(
    countSheetNo: countSheetNo,
    entries: lines,
    orgCode: auth?.organization.code ?? '',
    orgName: auth?.organization.name ?? '',
    printedBy: auth?.fullName ?? '',
  );
}

void _showError(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.redAccent,
    content: Text(e.toString().replaceFirst('Exception: ', '')),
  ));
}

/// Opens the system print dialog for the count sheet (on the web: the
/// browser's print dialog, which can also save it as a PDF).
Future<void> printCountSheet(
  BuildContext context,
  WidgetRef ref,
  String countSheetNo, {
  List<GateEntry>? entries,
}) async {
  try {
    final bytes = await runWithProgressDialog(
      context,
      () => _buildPdf(ref, countSheetNo, entries: entries),
      label: 'Preparing count sheet...',
    );
    await Printing.layoutPdf(
      name: _fileName(countSheetNo),
      format: PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  } catch (e) {
    if (context.mounted) _showError(context, e);
  }
}

/// Shows the count sheet on screen, with print, share and download in the
/// viewer's toolbar.
Future<void> viewCountSheet(
  BuildContext context,
  WidgetRef ref,
  String countSheetNo, {
  List<GateEntry>? entries,
}) async {
  try {
    final bytes = await runWithProgressDialog(
      context,
      () => _buildPdf(ref, countSheetNo, entries: entries),
      label: 'Preparing count sheet...',
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CountSheetPdfPage(countSheetNo: countSheetNo, bytes: bytes),
    ));
  } catch (e) {
    if (context.mounted) _showError(context, e);
  }
}

class _CountSheetPdfPage extends StatelessWidget {
  const _CountSheetPdfPage({required this.countSheetNo, required this.bytes});

  final String countSheetNo;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Count Sheet $countSheetNo')),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: _fileName(countSheetNo),
        initialPageFormat: PdfPageFormat.a4.landscape,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

/// After a save: offer to view or print the count sheet the entries went on.
Future<void> offerCountSheetPrint(
  BuildContext context,
  WidgetRef ref,
  String countSheetNo,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.fact_check_outlined,
          color: Theme.of(ctx).colorScheme.primary, size: 32),
      title: Text('Saved on Count Sheet $countSheetNo'),
      content: const Text(
        'Print the count sheet (Receipt and Put Away Sheet) for this vehicle now? '
        'You can also print it later from Count Sheets.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not now'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(ctx).pop('view'),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(ctx).pop('print'),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print Count Sheet'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (choice == 'print') {
    await printCountSheet(context, ref, countSheetNo);
  } else if (choice == 'view') {
    await viewCountSheet(context, ref, countSheetNo);
  }
}
