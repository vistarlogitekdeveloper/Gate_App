import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gate_entry_controller.dart';
import '../../../../core/auth/session_controller.dart';
import '../../../../core/auth/session_state.dart';
import '../../../reports/data/audit_repository_impl.dart';
import '../../data/gate_entry_repository_impl.dart';
import '../../data/dto/create_gate_entry_request.dart';
import '../../domain/models/gate_entry.dart';
import '../../domain/usecases/upload_gate_entry_attachment_usecase.dart';
import 'attachment_cache_controller.dart';

class GateEntryFormController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<GateEntry?> submit(Map<String, dynamic> params,
      {String? gateEntryId,
      String? attachmentFileName,
      String? attachmentPath,
      List<int>? bytes}) async {
    state = const AsyncLoading();
    try {
      final invoiceEntries = (params['invoice_entries'] as List<dynamic>? ??
              const <dynamic>[])
          .map((entry) {
            final rawQuantity = entry['quantity'];
            final quantity = rawQuantity is num
                ? rawQuantity.toInt()
                : int.tryParse((rawQuantity ?? '').toString()) ?? 0;
            return CreateGateEntryInvoiceEntryRequest(
              challanNo: (entry['challanNo'] ?? '').toString().trim(),
              documentDate: (entry['documentDate'] ?? '').toString().trim(),
              poNumber: (entry['poNumber'] ?? '').toString().trim(),
              partNumber: (entry['partNumber'] ?? '').toString().trim(),
              quantity: quantity,
              uom: (entry['uom'] ?? 'EA').toString().trim().toUpperCase(),
            );
          })
          .where((entry) => entry.challanNo.isNotEmpty)
          .toList();
      final invoiceChallanNos =
          invoiceEntries.map((entry) => entry.challanNo).toList();
      final challanNos = invoiceChallanNos.isNotEmpty
          ? invoiceChallanNos
          : (params['challan_nos'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
      final primaryChallanNo = challanNos.isNotEmpty
          ? challanNos.first
          : params['challan_no'].toString().trim();

      final isUpdate = gateEntryId != null && gateEntryId.isNotEmpty;
      final session = ref.read(sessionControllerProvider);
      final userId = session is Authenticated ? session.userId : 'Unknown';
      final role = session is Authenticated ? session.role.label : 'Unknown';
      GateEntry? createdEntry;

      if (isUpdate) {
        final updatePayload = _buildUpdatePayload(params);

        // Update existing entry
        final response = await ref
            .read(gateEntryRepositoryProvider)
            .updateGateEntry(gateEntryId, updatePayload);

        if (!response.success) {
          throw Exception(response.message.isNotEmpty
              ? response.message
              : 'Failed to update gate entry');
        }

        // Attachments for update (optional)
        if (attachmentFileName != null &&
            attachmentFileName.isNotEmpty &&
            (attachmentPath != null || bytes != null)) {
          await _handleAttachment(
              gateEntryId, attachmentFileName, attachmentPath, bytes);
        }

        _fireAndForget(() => ref.read(auditRepositoryProvider).logAction(
            userId,
            role,
            'Gate Entry',
            'Edit',
            'User updated Gate Entry $gateEntryId (Challan: ${params['challan_no']})'));
      } else {
        if (invoiceEntries.isEmpty) {
          throw Exception('At least one invoice entry is required');
        }

        // Create new entry
        final request = CreateGateEntryRequest(
          gateMovement: params['gate_movement'],
          vendorName: params['vendor_name'],
          vendorCode: params['vendor_code'],
          invoiceEntries: invoiceEntries,
          challanNo: primaryChallanNo,
          challanNos: challanNos.length > 1 ? challanNos : null,
          lrNumber: params['lr_number'],
          driverContactNo: params['driver_contact_no'],
          vehicleNo: params['vehicle_no'],
          transporterName: params['transporter_name'],
          noOfLineItems: _parseOptionalInt(params['no_of_line_items']),
          remark: _normalizeOptionalString(params['remark']),
        );

        final created = await ref
            .read(gateEntryControllerProvider.notifier)
            .createEntry(request);

        if (created == null) {
          throw Exception('Failed to create gate entry');
        }
        createdEntry = created;

        if (attachmentFileName != null &&
            attachmentFileName.isNotEmpty &&
            (attachmentPath != null || bytes != null) &&
            created.id.isNotEmpty) {
          await _runNonCritical(() => _handleAttachment(
              created.id, attachmentFileName, attachmentPath, bytes));
        }

        _fireAndForget(() => ref.read(auditRepositoryProvider).logAction(
            userId,
            role,
            'Gate Entry',
            'Create',
            'User triggered ${params['gate_movement']} Entry for Challan ${(challanNos.isNotEmpty ? challanNos.join(', ') : primaryChallanNo)} (Vendor: ${params['vendor_name']})'));
      }

      // List refresh runs in background; the list page also re-fetches on init.
      _fireAndForget(
        () => ref.read(gateEntryControllerProvider.notifier).fetchEntries(),
      );
      state = const AsyncData(null);
      return isUpdate ? null : createdEntry;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> _handleAttachment(String id, String fileName, String? path, List<int>? bytes) async {
    final uploadResponse = await ref
        .read(uploadGateEntryAttachmentUseCaseProvider)
        .execute(
          id,
          fileName: fileName,
          filePath: path,
          bytes: bytes,
        );

    if (!uploadResponse.success) {
      throw Exception(uploadResponse.message.isNotEmpty
          ? uploadResponse.message
          : 'Failed to upload attachment');
    }

    if (uploadResponse.data != null) {
      ref
          .read(attachmentCacheProvider.notifier)
          .addAttachment(id, uploadResponse.data!);
    }
  }

  void _fireAndForget(Future<void> Function() action) {
    Future.microtask(() async {
      try {
        await action();
      } catch (_) {
        // best-effort background work
      }
    });
  }

  Future<void> _runNonCritical(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Intentionally ignored: non-critical follow-up actions should not fail
      // gate entry creation/update UX when the main API call succeeded.
    }
  }

  Map<String, dynamic> _buildUpdatePayload(Map<String, dynamic> params) {
    final rawItems = (params['items'] as List?) ?? const [];
    final normalizedItems = rawItems.map((item) {
      final map = item as Map<String, dynamic>;
      return <String, dynamic>{
        'materialCode':
            (map['materialCode'] ?? map['material_code'] ?? '').toString(),
        'poNumber': (map['poNumber'] ?? map['po_number'] ?? '').toString(),
        'challanQty': map['challanQty'] ?? map['challan_qty'] ?? 0,
        'uom': (map['uom'] ?? 'Nos').toString(),
      };
    }).toList();

    // These keys MUST match updateBodySchema on the server. validate()
    // replaces req.body with the Zod-parsed object, so any key the schema does
    // not declare is deleted before the controller sees it. This map used to
    // be snake_case, so challanNo / vendorCode / vendorName never arrived and
    // the service fell back to the stored row — an admin could edit the
    // invoice number, vendor code or vendor name and nothing changed.
    final payload = <String, dynamic>{
      'gateMovement': params['gate_movement'],
      'vendorName': params['vendor_name'],
      'vendorCode': params['vendor_code'],
      'lrNumber': params['lr_number'],
      'driverContactNo': params['driver_contact_no'],
      'vehicleNo': params['vehicle_no'],
      'transporterName': params['transporter_name'],
      'items': normalizedItems,
    };

    // challanNo is min(1) server-side — sending '' would fail validation
    // outright, so only include it when there is one.
    final challanNo = (params['challan_no'] ?? '').toString().trim();
    if (challanNo.isNotEmpty) {
      payload['challanNo'] = challanNo;
    }

    // The invoice date lives on the first invoice row and was never sent on
    // an edit at all, so changing it did nothing either. The server wants a
    // plain YYYY-MM-DD date.
    final entries = params['invoice_entries'] as List<dynamic>? ?? const [];
    if (entries.isNotEmpty) {
      final first = entries.first;
      final documentDate = first is Map
          ? (first['documentDate'] ?? '').toString().trim()
          : '';
      // Plain YYYY-MM-DD shape check. Anything else is skipped rather than
      // sent, because the server validates this as a strict date and would
      // reject the whole edit over a half-typed one.
      final looksIsoDate = documentDate.length == 10 &&
          documentDate[4] == '-' &&
          documentDate[7] == '-' &&
          int.tryParse(documentDate.replaceAll('-', '')) != null;
      if (looksIsoDate) {
        payload['documentDate'] = documentDate;
      }
    }

    // noOfLineItems is deliberately NOT sent: no_of_line_items is neither
    // written nor read anywhere in the gate backend, so the server discards
    // it. Wire it up end to end (schema + service write + toPublic) before
    // sending it again, or the field silently does nothing.
    //
    // Omitting a field on PATCH preserves its existing server-side value.
    // The server field is 'remarks'; the singular 'remark' was discarded.
    final remark = _normalizeOptionalString(params['remark']);
    if (remark != null) {
      payload['remarks'] = remark;
    }

    return payload;
  }

  static int? _parseOptionalInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static String? _normalizeOptionalString(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}

final gateEntryFormControllerProvider =
    AsyncNotifierProvider<GateEntryFormController, void>(
  GateEntryFormController.new,
);

