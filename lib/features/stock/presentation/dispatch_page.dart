import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/stock_repository.dart';
import '../domain/stock_models.dart';

/// Dispatch stock: the lines chosen (one or several count sheets), how much of
/// each, and the vehicle taking them. Saving makes one Gate Out entry; security
/// records its Gate Out when the vehicle leaves. Pops true when dispatched.
class DispatchPage extends ConsumerStatefulWidget {
  const DispatchPage({super.key, required this.lines});
  final List<StockLine> lines;

  @override
  ConsumerState<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends ConsumerState<DispatchPage> {
  final _form = GlobalKey<FormState>();
  final _challan = TextEditingController();
  final _party = TextEditingController();
  final _partyCode = TextEditingController();
  final _vehicle = TextEditingController();
  final _transporter = TextEditingController();
  final _driver = TextEditingController();
  final _remarks = TextEditingController();
  DateTime _date = DateTime.now();
  late List<StockLine> _lines;
  late final Map<String, TextEditingController> _qty;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lines = [...widget.lines];
    _qty = {for (final l in _lines) l.key: TextEditingController(text: qtyLabel(l.balance))};
  }

  @override
  void dispose() {
    for (final c in [_challan, _party, _partyCode, _vehicle, _transporter, _driver, _remarks, ..._qty.values]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim());

  double get _total => _lines.fold(0.0, (sum, l) => sum + (_parse(_qty[l.key]!.text) ?? 0));

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_lines.isEmpty) return;
    setState(() => _saving = true);
    try {
      final result = await ref.read(stockRepositoryProvider).dispatch(
            challanNo: _challan.text.trim(),
            partyName: _party.text.trim(),
            partyCode: _partyCode.text.trim(),
            vehicleNo: _vehicle.text.trim(),
            transporterName: _transporter.text.trim(),
            driverContactNo: _driver.text.trim(),
            documentDate: _date,
            remarks: _remarks.text.trim(),
            lines: [for (final l in _lines) DispatchLineInput(line: l, qty: _parse(_qty[l.key]!.text)!)],
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 40),
          title: const Text('Dispatched'),
          content: Text(
            'Gate Out entry ${result.gateEntryNo} was made for ${_vehicle.text.trim()} '
            '(DC / invoice ${result.challanNo}, qty ${qtyLabel(_total)}).\n\n'
            'Security records the Gate Out when the vehicle leaves.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
        counterText: '',
      );

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final sheets = _lines.map((l) => l.countSheetNo).toSet().toList()..sort();
    const gap = SizedBox(height: 12);
    Widget pair(Widget a, Widget b) => mob
        ? Column(children: [a, gap, b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch stock')),
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(mob ? 16 : 24, 16, mob ? 16 : 24, 32),
          children: [
            Text(
              'From count sheet${sheets.length == 1 ? '' : 's'} ${sheets.join(', ')}. '
              'Saving makes one Gate Out entry for the vehicle.',
              style: muted,
            ),
            const SizedBox(height: 16),
            Text('Items', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final l in _lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VistarCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              [
                                'Count sheet ${l.countSheetNo}',
                                'Inv ${l.invoiceNo}',
                                if (l.poNumber != null && l.materialCode != null) 'PO ${l.poNumber}',
                              ].join(' · '),
                              style: muted,
                            ),
                            if (l.description != null) Text(l.description!, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('Balance ${qtyLabel(l.balance)}${l.uom == null ? '' : ' ${l.uom}'}',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _qty[l.key],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          textAlign: TextAlign.right,
                          decoration: _dec('Qty'),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final q = _parse(v ?? '');
                            if (q == null || q <= 0) return 'Enter qty';
                            if (q > l.balance + 1e-9) return 'Max ${qtyLabel(l.balance)}';
                            return null;
                          },
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(
                          tooltip: 'Leave out',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _saving ? null : () => setState(() => _lines.remove(l)),
                        ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total qty ${qtyLabel(_total)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 20),
            Text('Dispatch details', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            pair(
              TextFormField(
                controller: _challan,
                maxLength: 64,
                textCapitalization: TextCapitalization.characters,
                decoration: _dec('DC / invoice number *', icon: Icons.receipt_long_outlined),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the DC / invoice number' : null,
              ),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _dec('DC / invoice date', icon: Icons.event_outlined),
                  child: Text(DateFormat('dd MMM yyyy').format(_date)),
                ),
              ),
            ),
            gap,
            pair(
              TextFormField(
                controller: _party,
                maxLength: 200,
                decoration: _dec('Customer / party *', icon: Icons.storefront_outlined),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter who the goods go to' : null,
              ),
              TextFormField(
                controller: _partyCode,
                maxLength: 64,
                decoration: _dec('Customer code', icon: Icons.tag),
              ),
            ),
            gap,
            pair(
              TextFormField(
                controller: _vehicle,
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  TextInputFormatter.withFunction((_, n) => n.copyWith(text: n.text.toUpperCase())),
                ],
                decoration: _dec('Vehicle number *', hint: 'MH12AB1234', icon: Icons.local_shipping_outlined),
                validator: (v) => (v ?? '').trim().length < 4 ? 'Enter the vehicle number' : null,
              ),
              TextFormField(
                controller: _transporter,
                maxLength: 200,
                decoration: _dec('Transporter', icon: Icons.business_outlined),
              ),
            ),
            gap,
            pair(
              TextFormField(
                controller: _driver,
                maxLength: 10,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('Driver mobile', icon: Icons.phone_outlined),
                validator: (v) {
                  final s = (v ?? '').trim();
                  return s.isEmpty || s.length == 10 ? null : '10 digits';
                },
              ),
              TextFormField(
                controller: _remarks,
                maxLength: 500,
                decoration: _dec('Remarks', icon: Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving || _lines.isEmpty ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.outbox_rounded),
              label: Text('Dispatch ${qtyLabel(_total)}'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}
