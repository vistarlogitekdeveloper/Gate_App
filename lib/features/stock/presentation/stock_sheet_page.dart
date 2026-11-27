import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/vistar_card.dart';
import '../data/stock_repository.dart';
import '../domain/stock_models.dart';
import 'dispatch_page.dart';
import 'stock_widgets.dart';

/// One count sheet's stock: every invoice line (received, dispatched, balance)
/// and each dispatch taken from it.
class StockSheetPage extends ConsumerStatefulWidget {
  const StockSheetPage({super.key, required this.countSheetNo});
  final String countSheetNo;

  @override
  ConsumerState<StockSheetPage> createState() => _StockSheetPageState();
}

class _StockSheetPageState extends ConsumerState<StockSheetPage> {
  StockSheet? _sheet;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(stockRepositoryProvider).countSheet(widget.countSheetNo);
      if (!mounted) return;
      setState(() {
        _sheet = s;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _dispatch(List<StockLine> lines) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => DispatchPage(lines: lines)));
    if (done == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final mob = isMobile(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final canDispatch = ref.watch(stockSettingsProvider).valueOrNull?.canDispatch ?? false;
    final s = _sheet;
    final open = s?.lines.where((l) => l.balance > 0).toList() ?? const <StockLine>[];
    return Scaffold(
      appBar: AppBar(title: Text('Stock · Count Sheet ${widget.countSheetNo}')),
      floatingActionButton: canDispatch && open.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _dispatch(open),
              icon: const Icon(Icons.outbox_rounded),
              label: const Text('Dispatch'),
            )
          : null,
      body: s == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : StockMessage(icon: Icons.error_outline, text: _error!, color: theme.colorScheme.error),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(mob ? 16 : 24, 16, mob ? 16 : 24, 96),
                children: [
                  VistarCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Count Sheet ${s.countSheetNo}',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          [
                            if (s.vehicleNo != null) s.vehicleNo!,
                            ...s.vendors,
                            if (s.receivedAt != null) 'received ${stockDateTime.format(s.receivedAt!)}',
                          ].join(' · '),
                          style: muted,
                        ),
                        const SizedBox(height: 10),
                        StockTotalsRow(received: s.received, dispatched: s.dispatched, balance: s.balance),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Items', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final l in s.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VistarCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(
                                    [
                                      'Inv ${l.invoiceNo}',
                                      if (l.poNumber != null && l.materialCode != null) 'PO ${l.poNumber}',
                                      if (l.description != null) l.description!,
                                    ].join(' · '),
                                    style: muted,
                                  ),
                                  const SizedBox(height: 4),
                                  StockTotalsRow(received: l.received, dispatched: l.dispatched, balance: l.balance, dense: true),
                                ],
                              ),
                            ),
                            if (canDispatch && l.balance > 0)
                              TextButton(onPressed: () => _dispatch([l]), child: const Text('Dispatch')),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Dispatches (${s.dispatches.length})', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (s.dispatches.isEmpty)
                    Text('Nothing dispatched from this count sheet yet.', style: muted)
                  else
                    for (final d in s.dispatches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: VistarCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('${d.gateEntryNo} · DC ${d.challanNo}',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  Text(
                                    d.gatedOutAt == null ? 'Not gated out yet' : 'Gated out ${stockDateTime.format(d.gatedOutAt!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: d.gatedOutAt == null ? Colors.orange.shade800 : stockGreen,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                [
                                  if (d.partyName != null) d.partyName!,
                                  if (d.vehicleNo != null) d.vehicleNo!,
                                  if (d.createdAt != null) stockDateTime.format(d.createdAt!),
                                  if (d.createdBy != null) 'by ${d.createdBy}',
                                ].join(' · '),
                                style: muted,
                              ),
                              for (final l in d.lines)
                                Text('• ${l.materialCode ?? l.poNumber ?? 'Item'} (Inv ${l.invoiceNo}): ${qtyLabel(l.qty)}'),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
