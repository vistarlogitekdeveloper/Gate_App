import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/widgets/ribbon.dart';
import '../../data/vendor_repository_impl.dart';
import '../../domain/models/vendor.dart';
import '../controllers/vendor_providers.dart';

/// Shows the add/edit vendor dialog. Returns the created/updated [Vendor] when
/// the form is saved successfully, or `null` if the user cancelled.
Future<Vendor?> showVendorFormDialog(
  BuildContext context, {
  Vendor? existing,
}) {
  return showDialog<Vendor>(
    context: context,
    barrierDismissible: false,
    builder: (_) => VendorFormDialog(existing: existing),
  );
}

class VendorFormDialog extends ConsumerStatefulWidget {
  final Vendor? existing;

  const VendorFormDialog({super.key, this.existing});

  @override
  ConsumerState<VendorFormDialog> createState() => _VendorFormDialogState();
}

/// One purchase order row of the dialog.
class _PoRowFields {
  _PoRowFields({String po = '', String material = ''})
      : po = TextEditingController(text: po),
        material = TextEditingController(text: material);

  final TextEditingController po;
  final TextEditingController material;

  bool get isBlank => po.text.trim().isEmpty && material.text.trim().isEmpty;

  void dispose() {
    po.dispose();
    material.dispose();
  }
}

class _VendorFormDialogState extends ConsumerState<VendorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late VendorType _vendorType;
  late bool _isActive;
  bool _submitting = false;

  // The vendor's purchase orders and the material on each (vendor master
  // PO list). Editing: loaded from the server; saved only when changed.
  final List<_PoRowFields> _poRows = [];
  bool _loadingPos = false;
  String? _poLoadError;
  String _originalPos = '';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.existing?.vendorCode ?? '');
    _nameCtrl = TextEditingController(text: widget.existing?.vendorName ?? '');
    _vendorType = widget.existing?.vendorType ?? VendorType.purchase;
    _isActive = widget.existing?.isActive ?? true;
    if (_isEdit) {
      _loadPos();
    } else {
      _poRows.add(_PoRowFields());
    }
  }

  Future<void> _loadPos() async {
    setState(() {
      _loadingPos = true;
      _poLoadError = null;
    });
    try {
      final rows = await ref
          .read(vendorRepositoryProvider)
          .getVendorPurchaseOrders(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        for (final r in _poRows) {
          r.dispose();
        }
        _poRows
          ..clear()
          ..addAll(rows.map((r) =>
              _PoRowFields(po: r.poNumber, material: r.materialCode ?? '')));
        if (_poRows.isEmpty) _poRows.add(_PoRowFields());
        _originalPos = _poSignature(_collectPos());
        _loadingPos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPos = false;
        _poLoadError = _cleanError(e.toString());
      });
    }
  }

  /// setState for the PO section (built in an extension below).
  void _update(VoidCallback fn) => setState(fn);

  List<VendorPoRow> _collectPos() => [
        for (final r in _poRows)
          if (!r.isBlank)
            VendorPoRow(
              poNumber: r.po.text.trim(),
              materialCode: r.material.text.trim().isEmpty
                  ? null
                  : r.material.text.trim(),
            ),
      ];

  static String _poSignature(List<VendorPoRow> rows) {
    final keys = rows
        .map((r) => '${r.poNumber.toUpperCase()}|${(r.materialCode ?? '').toUpperCase()}')
        .toSet()
        .toList()
      ..sort();
    return keys.join(';');
  }

  /// The PO list to send: null when it is unchanged (or could not be loaded,
  /// so it must not be overwritten).
  List<VendorPoRow>? _posToSend() {
    if (_loadingPos || _poLoadError != null) return null;
    final rows = _collectPos();
    if (!_isEdit) return rows.isEmpty ? null : rows;
    return _poSignature(rows) == _originalPos ? null : rows;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    for (final r in _poRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(vendorActionControllerProvider.notifier);

    setState(() => _submitting = true);
    Vendor? result;
    String? errorMessage;
    try {
      if (_isEdit) {
        final existing = widget.existing!;
        // For PATCH only send changed fields.
        final request = VendorWriteRequest(
          vendorCode: _codeCtrl.text.trim() != existing.vendorCode
              ? _codeCtrl.text.trim()
              : null,
          vendorName: _nameCtrl.text.trim() != existing.vendorName
              ? _nameCtrl.text.trim()
              : null,
          vendorType:
              _vendorType != existing.vendorType ? _vendorType : null,
          isActive: _isActive != existing.isActive ? _isActive : null,
          purchaseOrders: _posToSend(),
        );
        // The backend requires at least one field; bail out early if nothing
        // changed so the user gets a clearer message than the server's 400.
        if (request.toJson().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No changes to save.')),
            );
            setState(() => _submitting = false);
          }
          return;
        }
        result = await controller.update(existing.id, request);
      } else {
        result = await controller.create(VendorWriteRequest(
          vendorCode: _codeCtrl.text.trim(),
          vendorName: _nameCtrl.text.trim(),
          vendorType: _vendorType,
          isActive: _isActive,
          purchaseOrders: _posToSend(),
        ));
      }
      if (result == null) {
        final lastErr = controller.lastError;
        errorMessage =
            lastErr != null ? lastErr.toString() : 'Could not save vendor.';
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
      return;
    }
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(
            _cleanError(errorMessage),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = mediaWidth < 620 ? mediaWidth - 32 : 560.0;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const RibbonAccentBar(height: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Vendor' : 'Add Vendor',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeCtrl,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vendor Code *',
                    hintText: 'e.g. 376902915',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vendor code is required';
                    }
                    if (v.trim().length > 64) {
                      return 'Vendor code is too long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Vendor Name *',
                    hintText: 'e.g. ASTRONIC TECHNOSYSTEMS LLP',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vendor name is required';
                    }
                    if (v.trim().length > 200) {
                      return 'Vendor name is too long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<VendorType>(
                  initialValue: _vendorType,
                  decoration: const InputDecoration(
                    labelText: 'Vendor Type *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: VendorType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          if (v != null) setState(() => _vendorType = v);
                        },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _isActive = v),
                  title: Text(
                    'Active',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Vendor is available for selection'
                        : 'Vendor is hidden from selection',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPoSection(theme),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RibbonButton(
                        label: _isEdit ? 'Save Changes' : 'Add Vendor',
                        icon: _isEdit
                            ? Icons.save_rounded
                            : Icons.add_circle_outline,
                        loading: _submitting,
                        fullWidth: true,
                        onPressed: _submitting ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on _VendorFormDialogState {
  Widget _buildPoSection(ThemeData theme) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    Widget poRow(int i) {
      final r = _poRows[i];
      final po = TextFormField(
        controller: r.po,
        enabled: !_submitting,
        decoration: const InputDecoration(
          labelText: 'PO Number',
          isDense: true,
          prefixIcon: Icon(Icons.request_quote_outlined, size: 20),
          counterText: '',
        ),
        maxLength: 64,
        validator: (v) {
          if ((v ?? '').trim().isEmpty && r.material.text.trim().isNotEmpty) {
            return 'Enter the PO of this material';
          }
          return null;
        },
      );
      final material = TextFormField(
        controller: r.material,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Material',
          isDense: true,
          prefixIcon: Icon(Icons.category_outlined, size: 20),
          counterText: '',
        ),
        maxLength: 64,
      );
      final remove = IconButton(
        tooltip: 'Remove this PO',
        onPressed: _submitting
            ? null
            : () => _update(() {
                  final removed = _poRows.removeAt(i);
                  removed.dispose();
                  if (_poRows.isEmpty) _poRows.add(_PoRowFields());
                }),
        icon: const Icon(Icons.remove_circle_outline),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: narrow
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(children: [
                      po,
                      const SizedBox(height: 8),
                      material,
                    ]),
                  ),
                  remove,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: po),
                  const SizedBox(width: 10),
                  Expanded(child: material),
                  remove,
                ],
              ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Purchase Orders & Materials',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10, right: 8),
            child: Text(
              'One row per PO and material. The gate entry form offers these '
              'when this vendor is chosen. Optional.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (_loadingPos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_poLoadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Could not load this vendor\'s POs: $_poLoadError',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  TextButton(onPressed: _loadPos, child: const Text('Retry')),
                ],
              ),
            )
          else ...[
            for (var i = 0; i < _poRows.length; i++) poRow(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _update(() => _poRows.add(_PoRowFields())),
                icon: const Icon(Icons.add),
                label: const Text('Add PO'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _cleanError(String raw) {
  // Strip noisy "Exception: " prefixes from thrown errors.
  return raw
      .replaceAll('Exception: ', '')
      .replaceAll('Exception:', '')
      .trim();
}
