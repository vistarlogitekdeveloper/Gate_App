// Stock per count sheet and dispatch against it (server: /stock). Optional:
// the organisation's admin switches it on.

String _s(Object? v) => v == null ? '' : v.toString();
String? _sn(Object? v) {
  final s = _s(v).trim();
  return s.isEmpty ? null : s;
}

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
DateTime? _t(Object? v) {
  final s = _sn(v);
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}

List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// 100 -> "100", 12.5 -> "12.5", 0.3333 -> "0.3333".
String qtyLabel(double q) {
  if (q == q.roundToDouble()) return q.toStringAsFixed(0);
  return q.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

class StockSettings {
  const StockSettings({required this.enabled, required this.canManage, required this.canDispatch});
  final bool enabled;
  final bool canManage;
  final bool canDispatch;

  factory StockSettings.fromJson(Map<String, dynamic> j) => StockSettings(
        enabled: j['enabled'] == true,
        canManage: j['canManage'] == true,
        canDispatch: j['canDispatch'] == true,
      );
}

/// One invoice line of a count sheet: received, dispatched, balance.
class StockLine {
  const StockLine({
    required this.entryId,
    required this.countSheetNo,
    required this.invoiceNo,
    this.vendorName,
    this.vehicleNo,
    this.poNumber,
    this.materialCode,
    this.description,
    this.uom,
    required this.received,
    required this.dispatched,
    required this.balance,
  });

  final String entryId;
  final String countSheetNo;
  final String invoiceNo;
  final String? vendorName;
  final String? vehicleNo;
  final String? poNumber;
  final String? materialCode;
  final String? description;
  final String? uom;
  final double received;
  final double dispatched;
  final double balance;

  /// Identifies the line across reloads (what the server keys it by).
  String get key => '$entryId|${poNumber ?? ''}|${materialCode ?? ''}';

  String get title => materialCode ?? poNumber ?? 'Item';

  factory StockLine.fromJson(Map<String, dynamic> j) => StockLine(
        entryId: _s(j['entryId']),
        countSheetNo: _s(j['countSheetNo']),
        invoiceNo: _s(j['invoiceNo']),
        vendorName: _sn(j['vendorName']),
        vehicleNo: _sn(j['vehicleNo']),
        poNumber: _sn(j['poNumber']),
        materialCode: _sn(j['materialCode']),
        description: _sn(j['description']),
        uom: _sn(j['uom']),
        received: _d(j['received']),
        dispatched: _d(j['dispatched']),
        balance: _d(j['balance']),
      );
}

class StockDispatchLine {
  const StockDispatchLine({required this.invoiceNo, this.poNumber, this.materialCode, required this.qty});
  final String invoiceNo;
  final String? poNumber;
  final String? materialCode;
  final double qty;
}

/// A dispatch taken (partly) from a count sheet.
class StockDispatch {
  const StockDispatch({
    required this.id,
    required this.gateEntryNo,
    required this.challanNo,
    this.partyName,
    this.vehicleNo,
    this.createdAt,
    this.createdBy,
    this.gatedOutAt,
    required this.lines,
  });

  final String id;
  final String gateEntryNo;
  final String challanNo;
  final String? partyName;
  final String? vehicleNo;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? gatedOutAt;
  final List<StockDispatchLine> lines;

  factory StockDispatch.fromJson(Map<String, dynamic> j) => StockDispatch(
        id: _s(j['id']),
        gateEntryNo: _s(j['gateEntryNo']),
        challanNo: _s(j['challanNo']),
        partyName: _sn(j['partyName']),
        vehicleNo: _sn(j['vehicleNo']),
        createdAt: _t(j['createdAt']),
        createdBy: _sn(j['createdBy']),
        gatedOutAt: _t(j['gatedOutAt']),
        lines: _list(j['lines'])
            .map((l) => StockDispatchLine(
                  invoiceNo: _s(l['invoiceNo']),
                  poNumber: _sn(l['poNumber']),
                  materialCode: _sn(l['materialCode']),
                  qty: _d(l['qty']),
                ))
            .toList(),
      );
}

/// A count sheet with its stock.
class StockSheet {
  const StockSheet({
    required this.countSheetNo,
    this.vehicleNo,
    this.receivedAt,
    required this.vendors,
    required this.invoices,
    required this.received,
    required this.dispatched,
    required this.balance,
    required this.lines,
    this.dispatchCount = 0,
    this.dispatches = const [],
  });

  final String countSheetNo;
  final String? vehicleNo;
  final DateTime? receivedAt;
  final List<String> vendors;
  final List<String> invoices;
  final double received;
  final double dispatched;
  final double balance;
  final List<StockLine> lines;
  final int dispatchCount;
  final List<StockDispatch> dispatches;

  factory StockSheet.fromJson(Map<String, dynamic> j) {
    final dispatches = _list(j['dispatches']).map(StockDispatch.fromJson).toList();
    return StockSheet(
      countSheetNo: _s(j['countSheetNo']),
      vehicleNo: _sn(j['vehicleNo']),
      receivedAt: _t(j['receivedAt']),
      vendors: j['vendors'] is List ? (j['vendors'] as List).map(_s).toList() : const [],
      invoices: j['invoices'] is List ? (j['invoices'] as List).map(_s).toList() : const [],
      received: _d(j['received']),
      dispatched: _d(j['dispatched']),
      balance: _d(j['balance']),
      lines: _list(j['lines']).map(StockLine.fromJson).toList(),
      // The list sends a count; one sheet's page sends the dispatches.
      dispatchCount: j['dispatches'] is num ? _i(j['dispatches']) : dispatches.length,
      dispatches: dispatches,
    );
  }
}

class StockTotals {
  const StockTotals({required this.received, required this.dispatched, required this.balance});
  final double received;
  final double dispatched;
  final double balance;

  factory StockTotals.fromJson(Map<String, dynamic> j) =>
      StockTotals(received: _d(j['received']), dispatched: _d(j['dispatched']), balance: _d(j['balance']));
}

class StockPage {
  const StockPage({required this.sheets, required this.page, required this.totalPages, required this.total});
  final List<StockSheet> sheets;
  final int page;
  final int totalPages;
  final int total;
}

/// What was dispatched: the Gate Out entry made for the vehicle.
class DispatchResult {
  const DispatchResult({required this.id, required this.gateEntryNo, required this.challanNo});
  final String id;
  final String gateEntryNo;
  final String challanNo;
}
