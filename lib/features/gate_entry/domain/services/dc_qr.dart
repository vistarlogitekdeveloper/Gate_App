import '../models/gate_entry.dart';

/// A delivery challan read off its QR (KB, 2026-11-14). QR Dispatch prints the
/// challan's details as plain text, first line "DELIVERY CHALLAN <DC no>",
/// with a "Vehicle: <no>" line; when the vehicle finished loading it also
/// made the Gate Out entry, with the DC number as its challan.
class DcQr {
  const DcQr({required this.dcNo, this.vehicleNo});
  final String dcNo;
  final String? vehicleNo;
}

final _header = RegExp(r'^\s*DELIVERY CHALLAN\s+(\S+)', caseSensitive: false);
final _vehicle = RegExp(r'^\s*Vehicle:\s*(.+?)\s*$', caseSensitive: false, multiLine: true);
final _bare = RegExp(r'^[A-Z]{1,4}\d{6,}$');

/// The DC number (and vehicle) in a scanned code; null when it is not a
/// delivery challan. A bare DC number ("DC2026000007") is taken as one.
DcQr? parseDcQr(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final head = _header.firstMatch(text);
  if (head != null) {
    final v = _vehicle.firstMatch(text)?.group(1);
    return DcQr(dcNo: head.group(1)!.toUpperCase(), vehicleNo: (v == null || v.isEmpty) ? null : v);
  }
  final bare = text.toUpperCase();
  return _bare.hasMatch(bare) ? DcQr(dcNo: bare) : null;
}

/// The Gate Out entry made for [dcNo]; never an inward entry that happens to
/// carry the same number.
GateEntry? pickOutEntry(Iterable<GateEntry> entries, String dcNo) {
  final want = dcNo.trim().toUpperCase();
  for (final e in entries) {
    if (e.gateMovement == GateMovement.outMovement && e.challanNo.trim().toUpperCase() == want) return e;
  }
  return null;
}

String _plate(String v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// True when the challan names a different lorry than the gate entry
/// ("MH 12 HV 3444" and "MH12-HV-3444" are the same one).
bool vehicleMismatch(String? onChallan, String? onEntry) {
  if (onChallan == null || onEntry == null) return false;
  final a = _plate(onChallan);
  final b = _plate(onEntry);
  return a.isNotEmpty && b.isNotEmpty && a != b;
}
