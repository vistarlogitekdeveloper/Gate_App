import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/pagination_model.dart';
import '../../../core/network/dio_provider.dart';
import '../../gate_entry/domain/models/gate_entry_summary.dart';
import '../domain/models/report_models.dart';
import '../domain/models/exception_report_item.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(apiClient: ref.read(apiClientProvider));
});

/// Tolerate qty fields the backend may return as num, decimal string
/// ("432.0000"), or null. Bare `as num` casts crash on the string form —
/// see warehouse_gate_entry.dart for the matching fix on the detail path.
num _readNum(dynamic value) {
  if (value is num) return value;
  if (value == null) return 0;
  return num.tryParse(value.toString()) ?? 0;
}

class ReportsRepository {
  final ApiClient _apiClient;

  ReportsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Map<String, dynamic> _buildQuery(
    ReportFilter filter, {
    bool includeLimit = true,
    int? page,
    int? limit,
    String? q,
    String? period,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? challan,
    String? vendor,
    String? po,
  }) {
    final query = <String, dynamic>{};
    // The previous default of 100,000 caused the server to return — and the
    // client to JSON-parse — every row in the table on every report load,
    // freezing the UI for seconds on busy sites. 500 covers the visible page
    // comfortably and keeps payloads under ~1 MB.
    if (includeLimit) {
      query['limit'] = limit ?? 500;
    } else if (limit != null) {
      query['limit'] = limit;
    }
    if (page != null) {
      query['page'] = page;
    }
    if (filter.startDate != null) {
      query['dateFrom'] = filter.startDate!.toIso8601String();
    }
    if (filter.endDate != null) {
      query['dateTo'] = filter.endDate!.toIso8601String();
    }
    if (filter.vendorFilter != null && filter.vendorFilter!.isNotEmpty) {
      query['vendor'] = filter.vendorFilter;
    }
    if (filter.poFilter != null && filter.poFilter!.isNotEmpty) {
      query['poNumber'] = filter.poFilter;
    }
    final hasExplicitRange =
        query.containsKey('dateFrom') || query.containsKey('dateTo');
    if (q != null && q.isNotEmpty) {
      query['q'] = q;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      query['sortBy'] = sortBy;
    }
    if (sortOrder != null && sortOrder.isNotEmpty) {
      query['sortOrder'] = sortOrder;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    if (challan != null && challan.isNotEmpty) {
      query['challan'] = challan;
    }
    if (vendor != null && vendor.isNotEmpty) {
      query['vendor'] = vendor;
    }
    if (po != null && po.isNotEmpty) {
      query['po'] = po;
    }
    if (!hasExplicitRange && period != null && period.isNotEmpty) {
      query['period'] = period;
    }
    return query;
  }

  List<dynamic> _extractList(dynamic response, {String key = 'data'}) {
    final root = response is Map<String, dynamic> ? response : const <String, dynamic>{};
    final data = root[key];

    if (data is List) return data;

    if (data is Map<String, dynamic>) {
      final candidates = [
        data['items'],
        data['records'],
        data['rows'],
        data['results'],
      ];
      for (final candidate in candidates) {
        if (candidate is List) return candidate;
      }
    }

    final topCandidates = [
      root['items'],
      root['records'],
      root['rows'],
      root['results'],
    ];
    for (final candidate in topCandidates) {
      if (candidate is List) return candidate;
    }

    return const [];
  }

  Future<List<GateEntryReportItem>> getGateEntryRegister(
    ReportFilter filter, {
    String? q,
    String? period,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? challan,
    String? vendor,
    String? po,
    int? limit,
  }) async {
    final response = await _apiClient.getRaw(
      '/gate-entries',
      queryParameters: _buildQuery(
        filter,
        includeLimit: false,
        limit: limit,
        q: q,
        period: period,
        sortBy: sortBy,
        sortOrder: sortOrder,
        status: status,
        challan: challan,
        vendor: vendor,
        po: po,
      ),
    );

    final success = response['success'] as bool? ?? false;
    if (!success) return [];
    final list = _extractList(response);
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      final items = map['items'];
      final itemList = items is List ? items : const [];
      final gateEntryNo = (map['gateEntryNo'] ?? map['gate_entry_no'] ?? '')
          .toString();
      final directionRaw =
          (map['gateMovement'] ?? map['gate_movement'] ?? '').toString();
      final challanNo =
          (map['challanNo'] ?? map['challan_no'] ?? map['invoiceNo'] ?? '')
              .toString();
      final lrNo = (map['lrNumber'] ?? map['lr_number'] ?? '').toString();
      final dateRaw =
          map['gateTimestamp'] ?? map['entryTime'] ?? map['createdAt'];
      final date = DateTime.tryParse(dateRaw?.toString() ?? '') ??
          DateTime.now();
      final gateOutRaw = map['gateOutTimestamp'] ??
          map['gate_out_timestamp'] ??
          map['gateOutTime'];
      final gateOutDate = DateTime.tryParse(gateOutRaw?.toString() ?? '');
      final isExited = gateOutDate != null;
      final direction = isExited ||
              directionRaw == 'out' ||
              directionRaw == 'outMovement'
          ? 'Gate Out'
          : 'Gate In';
      final vendor = (map['vendorName'] ?? map['vendor'] ?? '').toString();
      final vendorCode =
          (map['vendorCode'] ?? map['vendor_code'] ?? '').toString();
      final poNumber =
          (map['poNumber'] ?? map['po_number'] ?? '').toString();
      final vehicleNo =
          (map['vehicleNo'] ?? map['vehicleNumber'] ?? '').toString();
      final material = itemList.isNotEmpty
          ? ((itemList.first as Map<String, dynamic>)['materialCode'] ??
                  (itemList.first as Map<String, dynamic>)['material'] ??
                  '')
              .toString()
          : (map['materialCode'] ?? map['material'] ?? '').toString();
      final qty = itemList.isNotEmpty
          ? itemList.fold<int>(0, (sum, item) {
              final itemMap = item as Map<String, dynamic>;
              return sum +
                  _readNum(itemMap['challanQty'] ?? itemMap['challan_qty'])
                      .toInt();
            })
          : _readNum(map['qty'] ?? map['quantity']).toInt();
      final transporter =
          (map['transporterName'] ?? map['transporter'] ?? '').toString();
      final status =
          (map['statusLabel'] ?? map['status'] ?? 'Pending').toString();

      return GateEntryReportItem(
        gateEntryNo: gateEntryNo,
        direction: direction,
        challanNo: challanNo,
        lrNo: lrNo,
        date: date,
        gateOutDate: gateOutDate,
        material: material,
        qty: qty,
        vendor: vendor,
        vendorCode: vendorCode,
        transporter: transporter,
        vehicleNo: vehicleNo,
        poNumber: poNumber,
        status: status,
      );
    }).toList();
  }

  Future<GateEntryReportPage> getGateEntryRegisterPage(
    ReportFilter filter, {
    String? q,
    String? period,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? challan,
    String? vendor,
    String? po,
    int? page,
    int? limit,
  }) async {
    // Defence in depth against a null `limit` from callers.
    //
    // On 2026-09-15, the Reports page was observed shipping `limit: null`
    // through this call, `_buildQuery(includeLimit: false)` dropped the param
    // entirely, and the server responded with 2.1 MB / 9.3 s / 5000+ Flutter
    // exceptions during render because there was no cap at all. Even if a
    // page-level default lands, always cap here at 100 rows so a future bug
    // never repeats the same freeze. Server also caps at 100.
    final effectiveLimit = (limit == null || limit <= 0)
        ? 100
        : (limit > 100 ? 100 : limit);
    final effectivePage = page ?? 1;

    final response = await _apiClient.getRaw(
      '/gate-entries',
      queryParameters: _buildQuery(
        filter,
        includeLimit: false,
        page: effectivePage,
        limit: effectiveLimit,
        q: q,
        period: period,
        sortBy: sortBy,
        sortOrder: sortOrder,
        status: status,
        challan: challan,
        vendor: vendor,
        po: po,
      ),
    );

    final success = response['success'] as bool? ?? false;
    if (!success) return const GateEntryReportPage();
    final list = _extractList(response);
    final items = list.map((e) {
      final map = e as Map<String, dynamic>;
      final items = map['items'];
      final itemList = items is List ? items : const [];
      final gateEntryNo = (map['gateEntryNo'] ?? map['gate_entry_no'] ?? '')
          .toString();
      final directionRaw =
          (map['gateMovement'] ?? map['gate_movement'] ?? '').toString();
      final challanNo =
          (map['challanNo'] ?? map['challan_no'] ?? map['invoiceNo'] ?? '')
              .toString();
      final lrNo = (map['lrNumber'] ?? map['lr_number'] ?? '').toString();
      final dateRaw =
          map['gateTimestamp'] ?? map['entryTime'] ?? map['createdAt'];
      final date = DateTime.tryParse(dateRaw?.toString() ?? '') ??
          DateTime.now();
      final gateOutRaw = map['gateOutTimestamp'] ??
          map['gate_out_timestamp'] ??
          map['gateOutTime'];
      final gateOutDate = DateTime.tryParse(gateOutRaw?.toString() ?? '');
      final isExited = gateOutDate != null;
      final direction = isExited ||
              directionRaw == 'out' ||
              directionRaw == 'outMovement'
          ? 'Gate Out'
          : 'Gate In';
      final vendor = (map['vendorName'] ?? map['vendor'] ?? '').toString();
      final vendorCode =
          (map['vendorCode'] ?? map['vendor_code'] ?? '').toString();
      final poNumber =
          (map['poNumber'] ?? map['po_number'] ?? '').toString();
      final vehicleNo =
          (map['vehicleNo'] ?? map['vehicleNumber'] ?? '').toString();
      final material = itemList.isNotEmpty
          ? ((itemList.first as Map<String, dynamic>)['materialCode'] ??
                  (itemList.first as Map<String, dynamic>)['material'] ??
                  '')
              .toString()
          : (map['materialCode'] ?? map['material'] ?? '').toString();
      final qty = itemList.isNotEmpty
          ? itemList.fold<int>(0, (sum, item) {
              final itemMap = item as Map<String, dynamic>;
              return sum +
                  _readNum(itemMap['challanQty'] ?? itemMap['challan_qty'])
                      .toInt();
            })
          : _readNum(map['qty'] ?? map['quantity']).toInt();
      final transporter =
          (map['transporterName'] ?? map['transporter'] ?? '').toString();
      final status =
          (map['statusLabel'] ?? map['status'] ?? 'Pending').toString();

      return GateEntryReportItem(
        gateEntryNo: gateEntryNo,
        direction: direction,
        challanNo: challanNo,
        lrNo: lrNo,
        date: date,
        gateOutDate: gateOutDate,
        material: material,
        qty: qty,
        vendor: vendor,
        vendorCode: vendorCode,
        transporter: transporter,
        vehicleNo: vehicleNo,
        poNumber: poNumber,
        status: status,
      );
    }).toList();

    final summaryJson = response['summary'] as Map<String, dynamic>?;
    final paginationJson = response['pagination'] as Map<String, dynamic>?;

    return GateEntryReportPage(
      items: items,
      summary: summaryJson == null
          ? const GateEntrySummary()
          : GateEntrySummary.fromJson(summaryJson),
      pagination: paginationJson == null
          ? null
          : PaginationModel.fromJson(paginationJson),
    );
  }

  Future<List<GrnReconReportItem>> getGrnReconReport(
      ReportFilter filter) async {
    final response = await _apiClient.getRaw(
      '/reconciliations',
      queryParameters: _buildQuery(filter),
    );

    final success = response['success'] as bool? ?? false;
    if (!success) return [];
    final list = _extractList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) {
          try {
            return GrnReconReportItem.fromJson(json);
          } catch (_) {
            // Keep reports resilient even when one record has inconsistent typing.
            return GrnReconReportItem.fromJson({
              'gateEntryNo': (json['gateEntryNo'] ?? json['gate_entry_no'] ?? '').toString(),
              'grnNo': (json['grnNo'] ?? json['matchedGrnNumber'] ?? json['materialDocument'] ?? '').toString(),
              'poNumber': (json['poNumber'] ?? json['po_number'] ?? json['purchaseOrder'] ?? '').toString(),
              'challanNo': (json['challanNo'] ?? json['challan_no'] ?? json['referenceNo'] ?? '').toString(),
              'matchedStatus': (json['matchedStatus'] ?? json['statusLabel'] ?? json['status'] ?? '').toString(),
              'quantityDiff': json['quantityDiff'] ?? json['quantity_diff'] ?? json['qtyVariance'] ?? 0,
              'vendorName': (json['vendorName'] ?? json['vendor_name'] ?? json['vendor'] ?? '').toString(),
              'reconciledAt': (json['reconciledAt'] ?? json['createdAt'] ?? json['date'] ?? '').toString(),
              'remarks': (json['remarks'] ?? json['displayReason'] ?? '').toString(),
              'status': (json['status'] ?? json['statusLabel'] ?? '').toString(),
              'mdr': (json['mdr'] ?? json['reasonCode'] ?? '').toString(),
              'userName': (json['userName'] ?? json['reconciledBy'] ?? '').toString(),
            });
          }
        })
        .toList();
  }

  Future<List<ExceptionReportItem>> getExceptionReport(
      ReportFilter filter) async {
    final response = await _apiClient.getRaw(
      '/reconciliation/exceptions',
      queryParameters: _buildQuery(filter),
    );

    final success = response['success'] as bool? ?? false;
    if (!success) return [];
    final list = _extractList(response);

    // The exception payload identifies the gate entry but doesn't reliably
    // carry the vendor / invoice / part / qty captured at the gate. Pull the
    // gate-entry register for the same filter once and join by gate-entry
    // number so the report shows those human-readable fields. A failure here
    // must never break the core exception list, so fall back to an empty
    // lookup (enrichment columns just render blank).
    Map<String, GateEntryReportItem> gateEntryByNo = const {};
    try {
      // Scope the join to the SAME date window as the exceptions and hard-cap
      // it at 1000 rows. Previously this dropped the date bounds and sent no
      // limit, so it pulled the ENTIRE gate-entries table on every report load
      // — the exact unbounded fetch the 500-row cap in _buildQuery was added
      // to prevent ("freezing the UI for seconds on busy sites"). 1000 rows
      // comfortably covers the <=500 exceptions in the window; any gate entry
      // beyond that (or created just outside the window) simply renders blank
      // enrichment instead of hanging the report.
      final entries = await getGateEntryRegister(filter, limit: 1000);
      gateEntryByNo = {
        for (final entry in entries)
          if (entry.gateEntryNo.trim().isNotEmpty)
            entry.gateEntryNo.trim(): entry,
      };
    } catch (_) {
      // Non-fatal: leave enrichment fields blank if the join fetch fails.
    }

    return list.map((e) {
      final map = e as Map<String, dynamic>;
      final gateEntryId = map['gateEntryId']?.toString() ?? '';
      final gateEntryNo =
          (map['gateEntryNo'] ?? map['gate_entry_no'] ?? '').toString();
      final lookupKey =
          gateEntryNo.trim().isNotEmpty ? gateEntryNo.trim() : gateEntryId.trim();
      final entry = gateEntryByNo[lookupKey];

      // Prefer a value denormalised onto the exception payload; otherwise fall
      // back to the joined gate entry, then to empty.
      String pick(List<String> keys, String? joined) {
        for (final k in keys) {
          final raw = map[k];
          if (raw != null && raw.toString().trim().isNotEmpty) {
            return raw.toString();
          }
        }
        return joined ?? '';
      }

      final payloadQty = _readNum(map['qty'] ?? map['quantity']).toInt();

      return ExceptionReportItem(
        id: map['id']?.toString() ?? '',
        gateEntryId: gateEntryId,
        gateEntryNo: gateEntryNo.isNotEmpty ? gateEntryNo : gateEntryId,
        poNumber: (map['matchedGrnNumber'] ?? '').toString(),
        status: (map['statusLabel'] ?? map['status'] ?? '').toString(),
        description: (map['displayReason'] ?? map['reasonCode'] ?? '').toString(),
        createdAt: DateTime.tryParse(
                (map['reconciledAt'] ?? map['createdAt'])?.toString() ?? '') ??
            DateTime.now(),
        invoiceNo: pick(
            ['challanNo', 'challan_no', 'invoiceNo', 'invoice_no'],
            entry?.challanNo),
        partNo: pick(
            ['materialCode', 'material_code', 'material', 'partNo', 'part_no'],
            entry?.material),
        qty: payloadQty != 0 ? payloadQty : (entry?.qty ?? 0),
        vendorName:
            pick(['vendorName', 'vendor_name', 'vendor'], entry?.vendor),
        vendorCode:
            pick(['vendorCode', 'vendor_code'], entry?.vendorCode),
      );
    }).toList();
  }
}
