import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/vtt_models.dart';

final vttTime = DateFormat('hh:mm a');
final vttDateTime = DateFormat('dd MMM, hh:mm a');

String vttWhen(DateTime? at) {
  if (at == null) return '—';
  return DateUtils.isSameDay(at, DateTime.now()) ? vttTime.format(at) : vttDateTime.format(at);
}

/// Revised times show in this colour everywhere (SRS: "a different colour").
const vttRevisedColor = Color(0xFFE65100);

Color vttStatusColor(BuildContext context, String? status) => switch (status) {
      'green' => const Color(0xFF2E7D32),
      'amber' => const Color(0xFFEF8F00),
      'red' => const Color(0xFFD32F2F),
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };

String vttTripStatusLabel(String status) => switch (status) {
      'open' => 'Running',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };

Color vttTripStatusColor(String status) => switch (status) {
      'open' => const Color(0xFF1565C0),
      'completed' => const Color(0xFF2E7D32),
      _ => const Color(0xFF757575),
    };

class VttChip extends StatelessWidget {
  const VttChip({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );
}

/// "35m / target 60m" coloured by status.
class VttStepTime extends StatelessWidget {
  const VttStepTime({super.key, required this.minutes, this.target, this.status, this.prefix = ''});
  final int? minutes;
  final int? target;
  final String? status;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    if (minutes == null) return const SizedBox.shrink();
    final color = vttStatusColor(context, status);
    return Text(
      '$prefix${durationLabel(minutes)}${target == null ? '' : ' / target ${durationLabel(target)}'}',
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
    );
  }
}

/// Progress through the checkpoints: filled = recorded, ringed = next.
class VttProgressDots extends StatelessWidget {
  const VttProgressDots({super.key, required this.total, required this.done, this.status});
  final int total;
  final int done;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.primary;
    final off = theme.colorScheme.outlineVariant;
    final next = vttStatusColor(context, status);
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0)
            Expanded(child: Container(height: 2, color: i <= done - 1 ? on : off)),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? on : Colors.transparent,
              border: Border.all(color: i < done ? on : (i == done ? next : off), width: i == done ? 2.5 : 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class VttMessage extends StatelessWidget {
  const VttMessage({super.key, required this.icon, required this.text, this.color, this.action});
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 44, color: c),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

void vttSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? Colors.redAccent : null,
    content: Text(text),
  ));
}

String vttError(Object e) => e.toString().replaceFirst('Exception: ', '');

/// A required reason (corrections, closing a trip). Null when cancelled.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  String? message,
  String action = 'Save',
  List<String> quick = const [],
}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[Text(message), const SizedBox(height: 12)],
          if (quick.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final q in quick) ActionChip(label: Text(q), onPressed: () => ctrl.text = q)],
            ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = ctrl.text.trim();
            if (t.length >= 3) Navigator.pop(ctx, t);
          },
          child: Text(action),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}
