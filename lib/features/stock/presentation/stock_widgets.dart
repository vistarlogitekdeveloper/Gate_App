import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/stock_models.dart';

final stockDateTime = DateFormat('dd MMM, hh:mm a');

const stockGreen = Color(0xFF2E7D32);
const stockBlue = Color(0xFF1565C0);

/// "Received 100 · Dispatched 60 · Balance 40".
class StockTotalsRow extends StatelessWidget {
  const StockTotalsRow({super.key, required this.received, required this.dispatched, required this.balance, this.dense = false});
  final double received;
  final double dispatched;
  final double balance;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget cell(String label, double v, Color c) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label ', style: TextStyle(color: muted, fontSize: dense ? 12 : 13)),
            TextSpan(
              text: qtyLabel(v),
              style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: dense ? 13 : 15),
            ),
          ])),
        );
    return Wrap(
      runSpacing: 4,
      children: [
        cell('Received', received, Theme.of(context).colorScheme.onSurface),
        cell('Dispatched', dispatched, stockBlue),
        cell('Balance', balance, balance > 0 ? stockGreen : muted),
      ],
    );
  }
}

class StockMessage extends StatelessWidget {
  const StockMessage({super.key, required this.icon, required this.text, this.color, this.action});
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(children: [
        Icon(icon, size: 44, color: c),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ]),
    );
  }
}
