import 'package:freezed_annotation/freezed_annotation.dart';
import 'gate_entry_item.dart';

part 'gate_entry.freezed.dart';
part 'gate_entry.g.dart';

enum GateMovement { inMovement, outMovement }

@freezed
class GateEntry with _$GateEntry {
  const factory GateEntry({
    required String id,
    String? gateEntryNo,
    required GateMovement gateMovement,
    required String challanNo,
    @Default('') String lrNumber,
    required String transporterName,
    required String vehicleNo,
    @Default('') String driverContactNo,
    @Default('') String vendorCode,
    required String vendorName,
    required List<GateEntryItem> items,
    @Default('Pending') String status,
    DateTime? gateTimestamp,
    DateTime? gateOutTimestamp,
    String? gateOutBy,
    String? createdBy,
    int? noOfLineItems,
    String? remark,
    // The count sheet this entry was saved on (one per vehicle save, shared
    // by its invoices). Null for entries from before count sheets existed.
    String? countSheetNo,
  }) = _GateEntry;

  factory GateEntry.fromJson(Map<String, dynamic> json) =>
      _$GateEntryFromJson(json);
}
