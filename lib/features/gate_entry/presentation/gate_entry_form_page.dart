import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'controllers/gate_entry_form_controller.dart';
import '../../../core/network/api_response.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/loading_overlay.dart';
import '../../../core/ui/widgets/logout_action.dart';
import '../data/gate_entry_repository_impl.dart';
import '../domain/models/gate_entry.dart';
import '../domain/models/vendor.dart';
import '../domain/services/e_invoice_qr_parser.dart';
import '../domain/services/gate_pass_pdf_service.dart';
import 'gate_entry_detail_page.dart';
import '../domain/models/scanned_document.dart';
import '../domain/services/on_device_ocr.dart';
import 'widgets/e_invoice_qr_scanner_page.dart';
import 'widgets/scan_review_sheet.dart';

class _ChallanFieldState {
  _ChallanFieldState({
    String initialValue = '',
    String initialDocumentDate = '',
    String initialPoNumber = '',
    String initialPartNumber = '',
    String initialQuantity = '',
    String initialUom = 'EA',
  })  : controller = TextEditingController(text: initialValue),
        documentDateController =
            TextEditingController(text: initialDocumentDate),
        poNumberController = TextEditingController(text: initialPoNumber),
        partNumberController = TextEditingController(text: initialPartNumber),
        quantityController = TextEditingController(text: initialQuantity),
        uomController = TextEditingController(text: initialUom),
        focusNode = FocusNode();

  final TextEditingController controller;
  final TextEditingController documentDateController;
  final TextEditingController poNumberController;
  final TextEditingController partNumberController;
  final TextEditingController quantityController;
  final TextEditingController uomController;
  final FocusNode focusNode;

  bool isChecking = false;
  bool? isUnique;
  String? localError;
  String? serverError;
  String? lastCheckedValue;
  String? duplicateGateEntryId;
  String? duplicateGateEntryNo;

  bool get hasDuplicateEntryLink =>
      (duplicateGateEntryId ?? '').trim().isNotEmpty;

  bool get hasDuplicateWarning =>
      hasDuplicateEntryLink || (duplicateGateEntryNo ?? '').trim().isNotEmpty;

  String? get duplicateWarningText {
    if (!hasDuplicateWarning) return null;
    return 'Invoice already exists in this financial year '
        '(Entry: ${duplicateGateEntryNo?.trim().isNotEmpty == true ? duplicateGateEntryNo!.trim() : '-'})';
  }

  /// A duplicate invoice is a hard stop, not a hint.
  ///
  /// This used to return null whenever a duplicate was found, so the red
  /// warning under the field was purely decorative — the guard could still
  /// save, and the server then let it through too. One invoice number may be
  /// entered once per financial year, so it now blocks both the field
  /// validator and _checkAllChallansBeforeSubmit.
  ///
  /// The text stays short because the row underneath already spells out the
  /// financial year and links to the entry that owns the number.
  String? get blockingErrorText =>
      localError ??
      (hasDuplicateWarning ? 'Duplicate invoice — not allowed' : serverError);

  void clearRemoteState() {
    isUnique = null;
    serverError = null;
    lastCheckedValue = null;
    duplicateGateEntryId = null;
    duplicateGateEntryNo = null;
  }

  void dispose() {
    controller.dispose();
    documentDateController.dispose();
    poNumberController.dispose();
    partNumberController.dispose();
    quantityController.dispose();
    uomController.dispose();
    focusNode.dispose();
  }
}

class GateEntryFormPage extends ConsumerStatefulWidget {
  const GateEntryFormPage({super.key, this.initialEntry});

  final GateEntry? initialEntry;

  @override
  ConsumerState<GateEntryFormPage> createState() => _GateEntryFormPageState();
}

class _GateEntryFormPageState extends ConsumerState<GateEntryFormPage> {
  final _formKey = GlobalKey<FormState>();

  final List<_ChallanFieldState> _challanFields = [];
  final _vendorCodeCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _lrNumberCtrl = TextEditingController();
  final _driverContactCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  final _poCtrl = TextEditingController();
  final _transporterCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _noOfLineItemsCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  GateMovement _gateDirection = GateMovement.inMovement;
  String _materialCode = 'Parts';
  PlatformFile? _attachmentFile;

  // Vendor lookup states
  bool _isVendorFound = false;
  bool _isVendorNameReadOnly = false;
  bool _isLoadingVendorSuggestions = false;
  String? _lastLookedUpVendorCode;
  bool _isSelectingVendor = false;
  final List<Vendor> _vendorSuggestions = [];
  Timer? _vendorSuggestionDebounce;
  late final FocusNode _vendorCodeFocusNode;
  late final FocusNode _vendorNameFocusNode;

  // Challan uniqueness states
  bool _allowAlphaNumericChallan = false;
  bool _isScanning = false;
  Timer? _challanOnChangedDebounce;

  List<TextInputFormatter> get _challanInputFormatters {
    if (_allowAlphaNumericChallan) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9/-]')),
      ];
    }
    return [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9/-]')),
    ];
  }

  @override
  void initState() {
    super.initState();
    _vendorCodeFocusNode = FocusNode();
    _vendorNameFocusNode = FocusNode()
      ..addListener(() {
        if (!_vendorNameFocusNode.hasFocus && _vendorSuggestions.isNotEmpty) {
          // Delay clearing suggestions to allow the onTap gesture to complete
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted && !_isSelectingVendor) {
              setState(() => _vendorSuggestions.clear());
            }
          });
        }
      });

    if (widget.initialEntry != null) {
      final entry = widget.initialEntry!;
      _addChallanField(initialValue: entry.challanNo);
      _allowAlphaNumericChallan =
          !RegExp(r'^\d+$').hasMatch(entry.challanNo.trim());
      _vendorCodeCtrl.text = entry.vendorCode;
      _vendorCtrl.text = entry.vendorName;
      _lrNumberCtrl.text = entry.lrNumber;
      _driverContactCtrl.text = entry.driverContactNo;
      _vehicleCtrl.text = entry.vehicleNo;
      _transporterName();
      _gateDirection = entry.gateMovement;

      if (entry.items.isNotEmpty) {
        final first = entry.items.first;
        _poCtrl.text = first.poNumber;
        _materialCode =
            first.materialCode.isNotEmpty ? first.materialCode : 'Parts';
        _quantityCtrl.text = first.challanQty.toString();
        _challanFields.first.poNumberController.text = first.poNumber;
        _challanFields.first.partNumberController.text = first.materialCode;
        _challanFields.first.quantityController.text =
            first.challanQty.toString();
        _challanFields.first.uomController.text =
            first.uom.isNotEmpty ? first.uom : 'EA';
      }
      _materialCtrl.text = _materialCode;

      if (entry.noOfLineItems != null) {
        _noOfLineItemsCtrl.text = entry.noOfLineItems.toString();
      }
      if (entry.remark != null) {
        _remarkCtrl.text = entry.remark!;
      }

      _isVendorFound = true;
      _isVendorNameReadOnly = true;
      _lastLookedUpVendorCode = entry.vendorCode;
    } else {
      _materialCtrl.text = _materialCode;
      _addChallanField();
    }

    _vendorCodeCtrl.addListener(_onVendorCodeChangedForValidation);
  }

  void _onVendorCodeChangedForValidation() {
    final code = _vendorCodeCtrl.text.trim();
    // Only re-validate if the code has actually changed meaningfully
    if (code != _lastValidatedVendorCode) {
      _lastValidatedVendorCode = code;
      _revalidateAllChallans();
    }
  }

  String? _lastValidatedVendorCode;

  void _revalidateAllChallans() {
    // Re-check all non-empty challans with the new vendor context
    for (int i = 0; i < _challanFields.length; i++) {
      if (_challanFields[i].controller.text.trim().isNotEmpty) {
        _checkSingleChallan(i);
      }
    }
  }

  void _addChallanField({
    String initialValue = '',
    String initialDocumentDate = '',
    String initialPoNumber = '',
    String initialPartNumber = '',
    String initialQuantity = '',
    String initialUom = 'EA',
  }) {
    final field = _ChallanFieldState(
      initialValue: initialValue,
      initialDocumentDate: initialDocumentDate,
      initialPoNumber: initialPoNumber,
      initialPartNumber: initialPartNumber,
      initialQuantity: initialQuantity,
      initialUom: initialUom,
    );
    field.focusNode.addListener(() {
      if (!field.focusNode.hasFocus) {
        final index = _challanFields.indexOf(field);
        if (index != -1) {
          _checkSingleChallan(index);
        }
      }
    });
    _challanFields.add(field);
  }

  void _removeChallanField(int index) {
    if (_challanFields.length == 1) {
      _challanFields.first.controller.clear();
      _challanFields.first.documentDateController.clear();
      _challanFields.first.poNumberController.clear();
      _challanFields.first.partNumberController.clear();
      _challanFields.first.quantityController.clear();
      _challanFields.first.uomController.text = 'EA';
      _challanFields.first.clearRemoteState();
      _refreshLocalDuplicateErrors();
      setState(() {});
      return;
    }
    final field = _challanFields.removeAt(index);
    field.dispose();
    _refreshLocalDuplicateErrors();
    setState(() {});
  }

  List<String> _currentChallanNos() {
    return _challanFields
        .map((f) => f.controller.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _hasAnyChallanChecking() {
    return _challanFields.any((f) => f.isChecking);
  }

  void _onChallanFieldChanged(int index, String value) {
    if (index < 0 || index >= _challanFields.length) return;
    final field = _challanFields[index];

    // Most edits don't change anything the form needs to repaint immediately
    // (the TextField paints its own text). Only clear the remote-check state
    // once, on the first edit since the last validation, and debounce the
    // cross-field duplicate scan so we don't rebuild the whole form per keystroke.
    final hadRemoteState = field.isUnique != null ||
        field.serverError != null ||
        field.lastCheckedValue != null ||
        field.duplicateGateEntryId != null ||
        field.duplicateGateEntryNo != null;
    if (hadRemoteState) {
      field.clearRemoteState();
    }

    _challanOnChangedDebounce?.cancel();
    _challanOnChangedDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _refreshLocalDuplicateErrors();
      setState(() {});
    });
  }

  bool _refreshLocalDuplicateErrors() {
    final counts = <String, int>{};
    for (final f in _challanFields) {
      final text = f.controller.text.trim();
      if (text.isEmpty) continue;
      counts[text] = (counts[text] ?? 0) + 1;
    }

    var hasErrors = false;
    for (final f in _challanFields) {
      final text = f.controller.text.trim();
      if (text.isNotEmpty && (counts[text] ?? 0) > 1) {
        f.localError = 'Duplicate challan in this entry';
        hasErrors = true;
      } else {
        f.localError = null;
      }
    }
    return hasErrors;
  }

  /// India-style financial year (April 1 → March 31) for [when], formatted
  /// as "YYYY-YYYY" — e.g. 2025-01-15 → "2024-2025", 2025-05-15 → "2025-2026".
  /// Passed to the backend so the challan uniqueness check is scoped to the
  /// current FY rather than a per-vendor or all-time window.
  String _currentFinancialYear(DateTime when) {
    final startYear = when.month >= 4 ? when.year : when.year - 1;
    return '$startYear-${startYear + 1}';
  }

  bool _isCurrentEntryDuplicate({
    String? duplicateGateEntryId,
    String? duplicateGateEntryNo,
  }) {
    final editingEntry = widget.initialEntry;
    if (editingEntry == null) return false;

    final currentId = editingEntry.id.trim().toLowerCase();
    final currentNo = (editingEntry.gateEntryNo ?? '').trim().toLowerCase();
    final duplicateId = (duplicateGateEntryId ?? '').trim().toLowerCase();
    final duplicateNo = (duplicateGateEntryNo ?? '').trim().toLowerCase();

    if (duplicateId.isNotEmpty &&
        currentId.isNotEmpty &&
        duplicateId == currentId) {
      return true;
    }
    if (duplicateNo.isNotEmpty &&
        currentNo.isNotEmpty &&
        duplicateNo == currentNo) {
      return true;
    }
    return false;
  }

  Future<void> _checkSingleChallan(int index) async {
    if (index < 0 || index >= _challanFields.length) return;
    final field = _challanFields[index];
    final challanNo = field.controller.text.trim();

    _refreshLocalDuplicateErrors();
    if (field.localError != null) {
      setState(() {});
      return;
    }

    if (challanNo.isEmpty) {
      field.clearRemoteState();
      setState(() {});
      return;
    }

    if (field.isChecking || field.lastCheckedValue == challanNo) {
      return;
    }

    final formatOk = _allowAlphaNumericChallan
        ? RegExp(r'^[a-zA-Z0-9/-]+$').hasMatch(challanNo)
        : RegExp(r'^[0-9/-]+$').hasMatch(challanNo);
    if (!formatOk) return;

    setState(() {
      field.isChecking = true;
      field.serverError = null;
      field.isUnique = null;
    });

    try {
      final repo = ref.read(gateEntryRepositoryProvider);
      final vendorCode = _vendorCodeCtrl.text.trim();
      // Enforce cross-vendor duplicate detection for the invoice number by
      // scoping to the current financial year (April-March). Vendor code is
      // still passed so the backend can annotate the collision with the
      // right vendor, but the FY scope is what makes this an FY-wide check
      // rather than a per-vendor one.
      final result = await repo.checkChallanUniqueness(
        challanNo,
        vendorCode: vendorCode.isNotEmpty ? vendorCode : null,
        financialYear: _currentFinancialYear(DateTime.now()),
      );
      if (!mounted) return;

      setState(() {
        field.isChecking = false;
        field.lastCheckedValue = challanNo;
        if (result.success && result.data != null) {
          final unique = result.data!.data?.isUnique ?? false;
          final duplicateGateEntryId = result.data!.data?.existingGateEntryId;
          final duplicateGateEntryNo = result.data!.data?.existingGateEntryNo;
          final isCurrentEditEntry = _isCurrentEntryDuplicate(
            duplicateGateEntryId: duplicateGateEntryId,
            duplicateGateEntryNo: duplicateGateEntryNo,
          );

          field.isUnique = unique || isCurrentEditEntry;
          if (field.isUnique == true) {
            field.serverError = null;
            field.duplicateGateEntryId = null;
            field.duplicateGateEntryNo = null;
          } else {
            field.serverError =
                'Invoice already exists in this financial year '
                '(Entry: ${result.data!.data?.existingGateEntryNo ?? '-'})';
            field.duplicateGateEntryId = duplicateGateEntryId;
            field.duplicateGateEntryNo = duplicateGateEntryNo;
          }
        } else {
          final duplicateGateEntryId = result.data?.data?.existingGateEntryId;
          final duplicateGateEntryNo = result.data?.data?.existingGateEntryNo;
          final isCurrentEditEntry = _isCurrentEntryDuplicate(
            duplicateGateEntryId: duplicateGateEntryId,
            duplicateGateEntryNo: duplicateGateEntryNo,
          );

          field.isUnique = isCurrentEditEntry;
          if (isCurrentEditEntry) {
            field.serverError = null;
            field.duplicateGateEntryId = null;
            field.duplicateGateEntryNo = null;
          } else {
            field.serverError = result.message.isNotEmpty
                ? result.message
                : 'Failed to verify challan';
            field.duplicateGateEntryId = duplicateGateEntryId;
            field.duplicateGateEntryNo = duplicateGateEntryNo;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        field.isChecking = false;
        field.isUnique = false;
        field.lastCheckedValue = challanNo;
        field.serverError = 'Error checking challan uniqueness';
        field.duplicateGateEntryId = null;
        field.duplicateGateEntryNo = null;
      });
    }
  }

  Future<bool> _checkAllChallansBeforeSubmit() async {
    final hasLocalDuplicates = _refreshLocalDuplicateErrors();
    setState(() {});
    if (hasLocalDuplicates) return false;

    for (var i = 0; i < _challanFields.length; i++) {
      final text = _challanFields[i].controller.text.trim();
      if (text.isEmpty) continue;
      await _checkSingleChallan(i);
    }

    return !_challanFields.any((f) {
      final hasText = f.controller.text.trim().isNotEmpty;
      return hasText && f.blockingErrorText != null;
    });
  }

  void _transporterName() {
    final entry = widget.initialEntry;
    final name = entry?.transporterName;
    if (name != null) {
      _transporterCtrl.text = name;
    }
  }

  @override
  void dispose() {
    // The recogniser holds a native model; these phones do not have memory
    // to spare for a screen nobody is on.
    OnDeviceOcr.dispose();
    for (final field in _challanFields) {
      field.dispose();
    }
    _vendorCodeFocusNode.dispose();
    _vendorNameFocusNode.dispose();
    _vendorSuggestionDebounce?.cancel();
    _challanOnChangedDebounce?.cancel();
    _vendorCtrl.dispose();
    _vendorCodeCtrl.dispose();
    _lrNumberCtrl.dispose();
    _driverContactCtrl.dispose();
    _vehicleCtrl.dispose();
    _materialCtrl.dispose();
    _poCtrl.dispose();
    _transporterCtrl.dispose();
    _quantityCtrl.dispose();
    _noOfLineItemsCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _resetVendorLookupState({bool clearVendorName = false}) {
    setState(() {
      _isVendorFound = false;
      _isVendorNameReadOnly = false;
      _isLoadingVendorSuggestions = false;
      _lastLookedUpVendorCode = null;
      _vendorSuggestions.clear();
      if (clearVendorName) {
        _vendorCtrl.clear();
      }
    });
  }

  void _onVendorNameChanged(String value) {
    if (_isVendorNameReadOnly) return;
    final query = value.trim();
    _vendorSuggestionDebounce?.cancel();

    if (query.length < 2) {
      if (_vendorSuggestions.isNotEmpty || _isLoadingVendorSuggestions) {
        setState(() {
          _vendorSuggestions.clear();
          _isLoadingVendorSuggestions = false;
        });
      }
      return;
    }

    _vendorSuggestionDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchVendorSuggestions(query);
    });
  }

  Future<void> _fetchVendorSuggestions(String query) async {
    if (!mounted || _isVendorNameReadOnly) return;
    setState(() {
      _isLoadingVendorSuggestions = true;
    });

    final repo = ref.read(gateEntryRepositoryProvider);
    final result = await repo.searchVendors(query);

    if (!mounted) return;
    final currentQuery = _vendorCtrl.text.trim();
    if (currentQuery != query) {
      setState(() => _isLoadingVendorSuggestions = false);
      return;
    }

    setState(() {
      _isLoadingVendorSuggestions = false;
      _vendorSuggestions
        ..clear()
        ..addAll(
            result.success && result.data != null ? result.data! : const []);
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      setState(() {
        _attachmentFile = result.files.single;
      });
    }
  }

  Future<void> _pickDocumentDate(_ChallanFieldState field) async {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(field.documentDateController.text.trim());
    final initialDate = parsed ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    setState(() {
      field.documentDateController.text =
          DateFormat('yyyy-MM-dd').format(pickedDate);
    });
  }

  bool _isInvoiceRowTouched(_ChallanFieldState field) {
    return field.controller.text.trim().isNotEmpty ||
        field.documentDateController.text.trim().isNotEmpty ||
        field.poNumberController.text.trim().isNotEmpty ||
        field.partNumberController.text.trim().isNotEmpty ||
        field.quantityController.text.trim().isNotEmpty;
  }

  List<Map<String, dynamic>> _collectInvoiceEntries() {
    final entries = <Map<String, dynamic>>[];
    for (final field in _challanFields) {
      if (!_isInvoiceRowTouched(field)) continue;
      final qty = int.tryParse(field.quantityController.text.trim());
      final uom = field.uomController.text.trim().isEmpty
          ? 'EA'
          : field.uomController.text.trim().toUpperCase();
      entries.add({
        'challanNo': field.controller.text.trim(),
        'documentDate': field.documentDateController.text.trim(),
        'poNumber': field.poNumberController.text.trim(),
        'partNumber': field.partNumberController.text.trim(),
        'quantity': qty ?? 0,
        'uom': uom,
      });
    }
    return entries;
  }

  Future<void> _submit({bool printAfter = false}) async {
    if (_hasAnyChallanChecking()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, checking challan...')),
      );
      return;
    }

    final challanNos = _currentChallanNos();
    if (_formKey.currentState!.validate()) {
      if (challanNos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one challan is required')),
        );
        return;
      }

      final allValid = await _checkAllChallansBeforeSubmit();
      if (!mounted) return;
      if (!allValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please fix duplicate/invalid challans')),
        );
        return;
      }

      final isEdit = widget.initialEntry != null;
      final invoiceEntries = _collectInvoiceEntries();
      if (!isEdit && invoiceEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('At least one invoice entry is required')),
        );
        return;
      }

      final Map<String, dynamic> params = {
        'challan_no': challanNos.first,
        'challan_nos': challanNos,
        'vendor_name': _vendorCtrl.text.trim(),
        'vendor_code': _vendorCodeCtrl.text.trim(),
        'lr_number': _lrNumberCtrl.text.trim(),
        'driver_contact_no': _driverContactCtrl.text.trim(),
        'vehicle_no': _vehicleCtrl.text.trim(),
        'transporter_name': _transporterCtrl.text.trim(),
        'gate_movement':
            _gateDirection == GateMovement.inMovement ? 'in' : 'out',
        'invoice_entries': invoiceEntries,
        'no_of_line_items': _noOfLineItemsCtrl.text.trim(),
        'remark': _remarkCtrl.text.trim(),
      };

      if (isEdit) {
        final qty = int.tryParse(_quantityCtrl.text) ?? 0;
        params['items'] = [
          {
            'material_code': _materialCode,
            'po_number': _poCtrl.text.trim(),
            'challan_qty': qty,
          }
        ];
      }

      try {
        final createdEntry =
            await ref.read(gateEntryFormControllerProvider.notifier).submit(
                  params,
                  gateEntryId: widget.initialEntry?.id,
                  attachmentFileName: _attachmentFile?.name,
                  attachmentPath: kIsWeb ? null : _attachmentFile?.path,
                  bytes: _attachmentFile?.bytes,
                );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Gate Entry successfully updated!'
                : 'Gate Entry successfully created!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );

        if (printAfter && !isEdit && createdEntry != null) {
          try {
            // Pull items directly from the form so every challan number is
            // captured, even if the backend response doesn't include per-item
            // challan numbers yet.
            final items = <GatePassItemInfo>[];
            for (final field in _challanFields) {
              final challan = field.controller.text.trim();
              if (challan.isEmpty) continue;
              final qty =
                  int.tryParse(field.quantityController.text.trim()) ?? 0;
              items.add(GatePassItemInfo(
                materialCode: field.partNumberController.text.trim(),
                poNumber: field.poNumberController.text.trim(),
                challanQty: qty,
                uom: field.uomController.text.trim().isEmpty
                    ? 'EA'
                    : field.uomController.text.trim(),
                challanNo: challan,
              ));
            }

            await gatePassPdfService.printGatePassFromFields(
              gatePassNo: (createdEntry.gateEntryNo ?? '').trim().isNotEmpty
                  ? createdEntry.gateEntryNo!.trim()
                  : createdEntry.id,
              isInward: createdEntry.gateMovement == GateMovement.inMovement,
              entryDate: createdEntry.gateTimestamp,
              vendorName: createdEntry.vendorName,
              challanNo: createdEntry.challanNo,
              vehicleNo: createdEntry.vehicleNo,
              lrNumber: createdEntry.lrNumber,
              items: items.isNotEmpty
                  ? items
                  : createdEntry.items
                      .map((it) => GatePassItemInfo(
                            materialCode: it.materialCode,
                            poNumber: it.poNumber,
                            challanQty: it.challanQty,
                            uom: it.uom,
                            challanNo: it.challanNo,
                          ))
                      .toList(),
            );
          } catch (printError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open gate pass print: $printError'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.orangeAccent,
                ),
              );
            }
          }
        }

        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildChallanFields() {
    final isEdit = widget.initialEntry != null;
    final pattern = _allowAlphaNumericChallan
        ? RegExp(r'^[a-zA-Z0-9/-]+$')
        : RegExp(r'^[0-9/-]+$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _challanFields.length; i++) ...[
          TextFormField(
            controller: _challanFields[i].controller,
            focusNode: _challanFields[i].focusNode,
            inputFormatters: _challanInputFormatters,
            decoration: InputDecoration(
              labelText:
                  i == 0 ? 'Invoice/Challan Number' : 'Challan Number ${i + 1}',
              prefixIcon: const Icon(Icons.receipt_long),
              errorText: _challanFields[i].blockingErrorText,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canScanQr)
                    IconButton(
                      tooltip: 'Scan e-Invoice QR',
                      onPressed: () => _scanEInvoiceQrInto(i),
                      icon: Icon(
                        Icons.qr_code_scanner,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  if (i == 0)
                    IconButton(
                      tooltip: _allowAlphaNumericChallan
                          ? 'Alphanumeric enabled'
                          : 'Numeric only (tap to allow alphanumeric)',
                      onPressed: () {
                        setState(() {
                          _allowAlphaNumericChallan =
                              !_allowAlphaNumericChallan;
                          for (final field in _challanFields) {
                            field.clearRemoteState();
                          }
                        });
                      },
                      icon: Icon(
                        _allowAlphaNumericChallan
                            ? Icons.text_fields
                            : Icons.pin,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  if (i > 0)
                    IconButton(
                      tooltip: 'Remove challan',
                      onPressed: () => _removeChallanField(i),
                      icon: const Icon(Icons.close),
                    ),
                  if (_challanFields[i].isChecking)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_challanFields[i].isUnique == true &&
                      _challanFields[i].blockingErrorText == null &&
                      _challanFields[i].controller.text.trim().isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                ],
              ),
            ),
            onChanged: (value) {
              _onChallanFieldChanged(i, value);
            },
            onFieldSubmitted: (_) => _checkSingleChallan(i),
            validator: (value) {
              final text = (value ?? '').trim();
              if (i == 0 && _currentChallanNos().isEmpty) {
                return 'At least one challan is required';
              }
              if (!isEdit &&
                  text.isEmpty &&
                  _isInvoiceRowTouched(_challanFields[i])) {
                return 'Invoice/Challan number is required';
              }
              if (text.isEmpty) return null;
              if (!pattern.hasMatch(text)) {
                return _allowAlphaNumericChallan
                    ? 'Use only letters, numbers, / and -'
                    : 'Use only numbers, / and -';
              }
              return _challanFields[i].blockingErrorText;
            },
          ),
          if (_challanFields[i].duplicateWarningText != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: _challanFields[i].hasDuplicateEntryLink
                    ? () => _openDuplicateEntryDetail(
                          _challanFields[i].duplicateGateEntryId!,
                        )
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _challanFields[i].duplicateWarningText!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            decoration: _challanFields[i].hasDuplicateEntryLink
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildDesktopOrMobileRow(
            TextFormField(
              controller: _challanFields[i].documentDateController,
              readOnly: true,
              onTap: () => _pickDocumentDate(_challanFields[i]),
              decoration: const InputDecoration(
                labelText: 'Invoice Date',
                hintText: 'YYYY-MM-DD',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              validator: (value) {
                if (isEdit) return null;
                final required = _isInvoiceRowTouched(_challanFields[i]);
                if (!required) return null;
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Invoice date is required';
                if (DateTime.tryParse(text) == null) {
                  return 'Use a valid date';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _challanFields[i].poNumberController,
              decoration: const InputDecoration(
                labelText: 'PO Number (Optional)',
                prefixIcon: Icon(Icons.request_quote),
              ),
              validator: (_) => null,
            ),
          ),
          const SizedBox(height: 12),
          _buildDesktopOrMobileRow(
            TextFormField(
              controller: _challanFields[i].partNumberController,
              decoration: const InputDecoration(
                labelText: 'Part Number (Optional)',
                prefixIcon: Icon(Icons.category),
              ),
              validator: (_) => null,
            ),
            TextFormField(
              controller: _challanFields[i].quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantity (Optional)',
                prefixIcon: Icon(Icons.production_quantity_limits),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                final qty = int.tryParse(text);
                if (qty == null || qty <= 0) return 'Enter valid quantity';
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildDesktopOrMobileRow(
            DropdownButtonFormField<String>(
              initialValue: const [
                'EA',
                'NOS',
                'PCS',
                'KG',
                'BOX',
                'LITER',
                'ML',
                'GRAM',
              ].contains(_challanFields[i].uomController.text.trim())
                  ? _challanFields[i].uomController.text.trim()
                  : 'EA',
              decoration: const InputDecoration(
                labelText: 'UOM',
                prefixIcon: Icon(Icons.straighten),
              ),
              items: const [
                DropdownMenuItem(value: 'EA', child: Text('EA')),
                DropdownMenuItem(value: 'NOS', child: Text('NOS')),
                DropdownMenuItem(value: 'PCS', child: Text('PCS')),
                DropdownMenuItem(value: 'KG', child: Text('KG')),
                DropdownMenuItem(value: 'BOX', child: Text('BOX')),
                DropdownMenuItem(value: 'LITER', child: Text('Liter')),
                DropdownMenuItem(value: 'ML', child: Text('ML')),
                DropdownMenuItem(value: 'GRAM', child: Text('Gram')),
              ],
              onChanged: (value) {
                _challanFields[i].uomController.text = value ?? 'EA';
              },
              validator: (value) {
                if (isEdit) return null;
                final required = _isInvoiceRowTouched(_challanFields[i]);
                if (!required) return null;
                if ((value ?? '').trim().isEmpty) return 'UOM is required';
                return null;
              },
            ),
            const SizedBox.shrink(),
          ),
          if (_challanFields[i].hasDuplicateEntryLink)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openDuplicateEntryDetail(
                  _challanFields[i].duplicateGateEntryId!,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  'View existing entry${_challanFields[i].duplicateGateEntryNo?.isNotEmpty == true ? ' (${_challanFields[i].duplicateGateEntryNo!})' : ''}',
                ),
              ),
            ),
          if (i != _challanFields.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _addChallanField();
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Invoice/Challan'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 32.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopOrMobileRow(Widget child1, Widget child2) {
    final compactLayout = isMobile(context) || isTablet(context);
    if (compactLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child1,
          if (child2 is! SizedBox) const SizedBox(height: 16),
          child2,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child1),
        const SizedBox(width: 24),
        Expanded(child: child2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gateEntryFormControllerProvider);
    final isLoading = state.isLoading;
    final compactLayout = isMobile(context) || isTablet(context);
    final horizontalPadding = compactLayout ? 12.0 : 24.0;
    final cardPadding = compactLayout ? 18.0 : 32.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialEntry != null
            ? 'Edit Gate Entry'
            : 'Create Gate Entry'),
        actions: [
          // Scan-to-autofill. Offered only when CREATING: a scan fills a
          // fresh form, and dropping a scanned challan over an entry being
          // edited would silently overwrite values a person has already
          // reviewed and corrected.
          if (widget.initialEntry == null)
            _isScanning
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Scan challan or invoice',
                    icon: const Icon(Icons.document_scanner_outlined),
                    onPressed: _scanChallanPhoto,
                  ),
          const LogoutAction(),
          const SizedBox(width: 8),
        ],
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        message: widget.initialEntry != null
            ? 'Updating gate entry...'
            : 'Saving gate entry...',
        child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: 12.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialEntry != null
                            ? 'Update Entry Details'
                            : 'New Entry Details',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Provide accurate information for warehouse tracing and GRN matching.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // ── Section 1: Gate Information ──────────────────────
                      _buildSectionHeader(
                          '1. Gate Information', Icons.info_outline),
                      DropdownButtonFormField<GateMovement>(
                        isExpanded: true,
                        initialValue: _gateDirection,
                        decoration: const InputDecoration(
                            labelText: 'Gate Status',
                            prefixIcon: Icon(Icons.swap_horiz)),
                        items: const [
                          DropdownMenuItem(
                              value: GateMovement.inMovement,
                              child: Text('Gate In')),
                          DropdownMenuItem(
                              value: GateMovement.outMovement,
                              child: Text('Gate Out')),
                        ],
                        onChanged: (val) =>
                            setState(() => _gateDirection = val!),
                      ),
                      const SizedBox(height: 16),
                      _buildChallanFields(),

                      // ── Section 2: Vendor & Transport ────────────────────
                      _buildSectionHeader('2. Vendor & Transport',
                          Icons.local_shipping_outlined),

                      // Row 1: Vendor Name + Vendor Code
                      _buildDesktopOrMobileRow(
                        TextFormField(
                          controller: _vendorCtrl,
                          focusNode: _vendorNameFocusNode,
                          readOnly: _isVendorNameReadOnly,
                          decoration: InputDecoration(
                            labelText: 'Vendor Name',
                            prefixIcon: const Icon(Icons.storefront),
                            suffixIcon: _isVendorFound
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : (_isLoadingVendorSuggestions
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : null),
                            filled: _isVendorNameReadOnly,
                            fillColor: _isVendorNameReadOnly
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5)
                                : null,
                          ),
                          onChanged: _onVendorNameChanged,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Vendor name is required'
                              : null,
                        ),
                        TextFormField(
                          controller: _vendorCodeCtrl,
                          focusNode: _vendorCodeFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Vendor Code (Optional)',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onChanged: (value) {
                            // Only reset if the user is actually typing/changing the value,
                            // not if it's the same as the last selection/lookup.
                            if (_isVendorFound &&
                                value == _lastLookedUpVendorCode) {
                              return;
                            }

                            if (_isVendorFound || _isVendorNameReadOnly) {
                              _resetVendorLookupState(clearVendorName: false);
                            }
                          },
                          // Removed mandatory validation and lookup
                        ),
                      ),
                      if (!_isVendorNameReadOnly &&
                          _vendorSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _vendorSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _vendorSuggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  suggestion.vendorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(suggestion.vendorCode),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 14),
                                onTap: () async {
                                  // Mark as selecting to prevent focus loss from clearing suggestions
                                  _isSelectingVendor = true;

                                  setState(() {
                                    // 1. Update controllers
                                    _vendorCtrl.text = suggestion.vendorName;
                                    _vendorCodeCtrl.text =
                                        suggestion.vendorCode;

                                    // 2. Update lookup states
                                    _lastLookedUpVendorCode =
                                        suggestion.vendorCode;
                                    _isVendorFound = true;
                                    _isVendorNameReadOnly = true;

                                    // 3. Clear suggestions
                                    _vendorSuggestions.clear();
                                    _isLoadingVendorSuggestions = false;
                                  });

                                  // Give a tiny frame gap for state to settle
                                  await Future.delayed(Duration.zero);

                                  // 4. Clear focus
                                  _vendorNameFocusNode.unfocus();
                                  _vendorCodeFocusNode.unfocus();

                                  _isSelectingVendor = false;
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Row 2: LR Number + Driver Contact No
                      _buildDesktopOrMobileRow(
                          TextFormField(
                            controller: _lrNumberCtrl,
                            decoration: const InputDecoration(
                                labelText: 'LR Number',
                                prefixIcon: Icon(Icons.confirmation_number)),
                          ),
                          TextFormField(
                            controller: _driverContactCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Driver Contact No *',
                              prefixIcon: Icon(Icons.phone_android),
                              counterText: '',
                              helperText: '10-digit mobile number required',
                            ),
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) {
                              final max = maxLength ?? 10;
                              final remaining = max - currentLength;
                              final isComplete = remaining == 0;
                              final label = isComplete
                                  ? 'Complete ($currentLength/$max)'
                                  : '$remaining digit${remaining == 1 ? '' : 's'} remaining ($currentLength/$max)';
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isComplete
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isComplete
                                        ? Colors.green
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Driver contact number is required';
                              }
                              if (!RegExp(r'^\d{10}$').hasMatch(text)) {
                                return 'Mobile number must be exactly 10 digits';
                              }
                              return null;
                            },
                          )),
                      const SizedBox(height: 16),

                      // Row 3: Transporter Name + Vehicle Number
                      _buildDesktopOrMobileRow(
                          TextFormField(
                            controller: _transporterCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Transporter Name',
                                prefixIcon: Icon(Icons.local_shipping)),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Transporter is required'
                                : null,
                          ),
                          TextFormField(
                            controller: _vehicleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle Number',
                              prefixIcon: Icon(Icons.numbers),
                              counterText: '',
                              helperText: 'Up to 10 characters',
                            ),
                            maxLength: 10,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]')),
                              LengthLimitingTextInputFormatter(10),
                              TextInputFormatter.withFunction(
                                (oldValue, newValue) => newValue.copyWith(
                                    text: newValue.text.toUpperCase()),
                              ),
                            ],
                            buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$currentLength / ${maxLength ?? 10}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: currentLength == (maxLength ?? 10)
                                        ? Colors.green
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Vehicle number required';
                              }
                              if (text.length > 10) {
                                return 'Maximum 10 characters';
                              }
                              return null;
                            },
                          )),

                      const SizedBox(height: 16),
                      _buildDesktopOrMobileRow(
                        TextFormField(
                          controller: _noOfLineItemsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'No. of Line Items (optional)',
                            prefixIcon: Icon(Icons.format_list_numbered),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return null;
                            return int.tryParse(text) == null
                                ? 'Must be a whole number'
                                : null;
                          },
                        ),
                        const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Remark (optional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),

                      // ── Section 3: Material Details ──────────────────────
                      if (widget.initialEntry != null) ...[
                        _buildSectionHeader(
                            '3. Material Details', Icons.inventory_2_outlined),
                        _buildDesktopOrMobileRow(
                          TextFormField(
                            controller: _materialCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Material Name (Optional)',
                              prefixIcon: Icon(Icons.category),
                            ),
                            onChanged: (value) => _materialCode = value.trim(),
                            validator: (_) => null,
                          ),
                          TextFormField(
                            controller: _poCtrl,
                            decoration: const InputDecoration(
                                labelText: 'PO Number (Optional)',
                                prefixIcon: Icon(Icons.request_quote)),
                            validator: (_) => null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDesktopOrMobileRow(
                          TextFormField(
                            controller: _quantityCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Quantity (Optional)',
                                prefixIcon:
                                    Icon(Icons.production_quantity_limits),
                                helperText: 'Enter exact numerical quantity.'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) return null;
                              if (int.tryParse(value) == null) {
                                return 'Must be a valid integer';
                              }
                              return null;
                            },
                          ),
                          const SizedBox.shrink(),
                        ),
                      ],

                      // ── Attachments ──────────────────────────────────────
                      _buildSectionHeader(
                        widget.initialEntry != null
                            ? '4. Attachments'
                            : '3. Attachments',
                        Icons.attachment,
                      ),
                      Container(
                        padding: EdgeInsets.all(compactLayout ? 16 : 24),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickAttachment,
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Browse Files'),
                            ),
                            const SizedBox(height: 12),
                            if (_attachmentFile != null)
                              Row(
                                children: [
                                  const Icon(Icons.insert_drive_file,
                                      color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _attachmentFile!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _attachmentFile = null;
                                      });
                                    },
                                  )
                                ],
                              )
                            else
                              Text(
                                'No file selected',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: compactLayout ? 32 : 48),
                      _buildSubmitActions(
                        isLoading: isLoading,
                        compactLayout: compactLayout,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSubmitActions({
    required bool isLoading,
    required bool compactLayout,
  }) {
    final isEdit = widget.initialEntry != null;
    final buttonHeight = compactLayout ? 52.0 : 56.0;

    final confirmLabel = isLoading
        ? const SizedBox(
            height: 24,
            width: 24,
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
        : Text(
            isEdit ? 'Update Gate Entry' : 'Confirm Gate Entry',
            style: const TextStyle(fontSize: 16),
          );

    final confirmButton = SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: FilledButton.icon(
        onPressed: isLoading ? null : () => _submit(),
        icon: isLoading ? const SizedBox.shrink() : const Icon(Icons.save),
        label: confirmLabel,
      ),
    );

    if (isEdit) {
      return confirmButton;
    }

    final printButton = SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : () => _submit(printAfter: true),
        icon: const Icon(Icons.print),
        label: const Text(
          'Confirm & Print Gate Pass',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );

    return Column(
      children: [
        confirmButton,
        const SizedBox(height: 12),
        printButton,
      ],
    );
  }

  bool get _canScanQr {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _scanEInvoiceQrInto(int rowIndex) async {
    if (rowIndex < 0 || rowIndex >= _challanFields.length) return;

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const EInvoiceQrScannerPage(),
      ),
    );
    if (!mounted || raw == null || raw.isEmpty) return;

    final parsed = EInvoiceQrData.tryParse(raw);
    if (parsed == null || !parsed.hasAnyData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read QR. Try again or enter manually.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final docNo = (parsed.docNo ?? '').trim();
    final docDateIso = parsed.docDateIso;
    final target = _challanFields[rowIndex];

    setState(() {
      if (docNo.isNotEmpty) {
        target.controller.text = docNo;
        if (!RegExp(r'^[0-9/-]+$').hasMatch(docNo)) {
          _allowAlphaNumericChallan = true;
        }
        target.clearRemoteState();
      }
      if (docDateIso != null && docDateIso.isNotEmpty) {
        target.documentDateController.text = docDateIso;
      }
      _refreshLocalDuplicateErrors();
    });

    if (docNo.isNotEmpty) {
      // ignore: unawaited_futures
      _checkSingleChallan(rowIndex);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          docNo.isEmpty
              ? 'QR scanned. Please verify and complete the row.'
              : 'Scanned invoice $docNo into row ${rowIndex + 1}.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Photograph a challan / invoice and prefill the form from it.
  ///
  /// Deliberately a THREE step flow — capture, review, apply — rather than
  /// capture-and-fill. The backend returns a confidence per field and flags
  /// what it is unsure about, and pouring that straight into the form would
  /// trade typing mistakes for something worse: a wrong value nobody looked
  /// at, saved with the same confidence as a correct one. So everything goes
  /// through [ScanReviewSheet] first.
  Future<void> _scanChallanPhoto() async {
    if (_isScanning) return;

    final picker = ImagePicker();
    XFile? shot;

    // On low-RAM Android devices (common at the gate), Android can kill this
    // process while the system camera activity is fullscreen. When it does,
    // image_picker stashes the returned photo for us — pick it up here before
    // asking the guard to shoot the same paper twice.
    if (!kIsWeb) {
      try {
        final lost = await picker.retrieveLostData();
        if (lost.file != null && lost.exception == null) {
          shot = lost.file;
        }
      } catch (_) {
        // Recovery is best-effort; a failure here just means we fall through
        // to the fresh camera launch below.
      }
    }

    if (shot == null) {
      try {
        shot = await picker.pickImage(
          // A guard at the barrier is holding the paper, so the camera is the
          // point. On web there is no camera worth using, so fall back to a
          // file chooser (the desk use-case is a PDF or a photo off email).
          source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
          // The backend normalises to a 2200px long edge before OCR, so a
          // larger upload buys nothing and costs the guard time on a gate's
          // mobile connection. 88% JPEG keeps small print crisp — going lower
          // starts eating the thin strokes OCR needs.
          maxWidth: 2400,
          imageQuality: 88,
        );
      } catch (e) {
        if (!mounted) return;
        _showScanMessage('Could not open the camera: $e', isError: true);
        return;
      }
    }
    if (shot == null || !mounted) return;

    setState(() => _isScanning = true);
    ApiResponse<ScannedDocument> result;
    try {
      final repo = ref.read(gateEntryRepositoryProvider);

      // Read the page HERE first. ML Kit is built for camera frames and beats
      // server-side Tesseract on a handheld photo — every early production
      // scan came back flagged blurred. It costs well under a second and
      // needs no network, so it happens before the upload rather than
      // instead of it: the photo still goes up, so the server can fall back
      // and so both engines can be judged on identical input.
      //
      // Null means recognition was unavailable or found nothing (web, a
      // model still downloading, a device without Play Services). That is
      // not an error — the server reads the photo exactly as it does today.
      String? recognized;
      if (!kIsWeb) {
        final payload = await OnDeviceOcr.recognise(shot.path);
        if (payload != null) recognized = OnDeviceOcr.encode(payload);
      }

      // Mobile gives us a real file path; web only gives bytes.
      result = await repo.scanDocument(
        fileName: shot.name.isEmpty ? 'challan.jpg' : shot.name,
        filePath: kIsWeb ? null : shot.path,
        bytes: kIsWeb ? await shot.readAsBytes() : null,
        recognized: recognized,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _showScanMessage('Scan failed: $e', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isScanning = false);

    if (!result.success || result.data == null) {
      final reason = result.error?.message ??
          (result.message.isNotEmpty ? result.message : null);
      _showScanMessage(
        reason ?? 'Scan failed. Enter the entry manually.',
        isError: true,
      );
      return;
    }

    final scan = result.data!;
    final accepted = await ScanReviewSheet.show(
      context,
      scan: scan,
      // Retake loops straight back into the camera. On a blurred photo that
      // fixes more than correcting six fields by hand does.
      onRetake: _scanChallanPhoto,
    );
    if (accepted == null || !mounted) return;

    _applyScannedValues(accepted);
  }

  /// Write reviewed values into the form controllers.
  ///
  /// Only keys the guard kept in the sheet arrive here, so this does not
  /// second-guess them — it maps names to controllers and then re-runs the
  /// form's own validation, which is what catches a duplicate challan or a
  /// vendor code that no longer resolves.
  void _applyScannedValues(Map<String, dynamic> values) {
    String? str(String key) {
      final v = values[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    setState(() {
      final challanNo = str('challanNo');
      if (challanNo != null && _challanFields.isNotEmpty) {
        _challanFields.first.controller.text = challanNo;
        // Real challan numbers are frequently alphanumeric — verified against
        // the live gate database, forms like "TI/262701655" and
        // "GSAAC6/37006" are common — so the numeric-only input formatter has
        // to be relaxed or the value we just read would be stripped as the
        // user touches the field.
        if (!RegExp(r'^[0-9/-]+$').hasMatch(challanNo)) {
          _allowAlphaNumericChallan = true;
        }
        _challanFields.first.clearRemoteState();
      }

      final documentDate = str('documentDate');
      if (documentDate != null && _challanFields.isNotEmpty) {
        _challanFields.first.documentDateController.text = documentDate;
      }

      final vendorCode = str('vendorCode');
      if (vendorCode != null) _vendorCodeCtrl.text = vendorCode;
      final vendorName = str('vendorName');
      if (vendorName != null) _vendorCtrl.text = vendorName;

      final vehicleNo = str('vehicleNo');
      if (vehicleNo != null) _vehicleCtrl.text = vehicleNo;
      final transporter = str('transporterName');
      if (transporter != null) _transporterCtrl.text = transporter;
      final lrNumber = str('lrNumber');
      if (lrNumber != null) _lrNumberCtrl.text = lrNumber;
      final driverContact = str('driverContactNo');
      if (driverContact != null) _driverContactCtrl.text = driverContact;

      // Line items. Only the first row is filled: the form starts with one
      // challan row, and silently adding rows for every invoice line would
      // hand the guard a form to prune rather than one to check.
      final items = values['items'];
      if (items is List && items.isNotEmpty && _challanFields.isNotEmpty) {
        final first = items.first;
        if (first is Map) {
          final row = _challanFields.first;
          final po = (first['poNumber'] ?? '').toString().trim();
          final part = (first['materialCode'] ?? '').toString().trim();
          final qty = first['challanQty'];
          final uom = (first['uom'] ?? '').toString().trim();
          if (po.isNotEmpty) {
            row.poNumberController.text = po;
            _poCtrl.text = po;
          }
          if (part.isNotEmpty) {
            row.partNumberController.text = part;
            _materialCtrl.text = part;
          }
          if (qty != null) {
            row.quantityController.text = qty.toString();
            _quantityCtrl.text = qty.toString();
          }
          if (uom.isNotEmpty) row.uomController.text = uom;
        }
      }

      _refreshLocalDuplicateErrors();
    });

    // Re-run the server-side challan check on what was just filled. The scan
    // already reported a duplicate, but the form owns that state and the
    // guard may have picked a different vendor in the sheet — which changes
    // the answer, since the rule is per (challan, vendor).
    if (_challanFields.isNotEmpty &&
        _challanFields.first.controller.text.trim().isNotEmpty) {
      // ignore: unawaited_futures
      _checkSingleChallan(0);
    }

    if (!mounted) return;
    _showScanMessage(
      'Filled ${values.keys.where((k) => k != 'items').length} field(s) from the document. Check the highlighted ones before saving.',
    );
  }

  void _showScanMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: Duration(seconds: isError ? 5 : 4),
      ),
    );
  }

  void _openDuplicateEntryDetail(String duplicateId) {
    if (duplicateId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GateEntryDetailPage(entryId: duplicateId),
      ),
    );
  }
}
