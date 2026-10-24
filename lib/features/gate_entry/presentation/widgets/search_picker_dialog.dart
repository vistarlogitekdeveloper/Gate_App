import 'dart:async';

import 'package:flutter/material.dart';

/// A searchable list in a dialog; returns the picked item or null.
///
/// [load] is called with the search text (debounced) and may hit the server.
/// Results of an older search never replace a newer one. Below [minChars]
/// characters [load] is not called and [hint] is shown instead.
Future<T?> showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required Future<List<T>> Function(String query) load,
  required String Function(T item) titleOf,
  String? Function(T item)? subtitleOf,
  String searchHint = 'Search',
  String emptyText = 'Nothing found',
  String? hint,
  int minChars = 0,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => _SearchPickerDialog<T>(
      title: title,
      load: load,
      titleOf: titleOf,
      subtitleOf: subtitleOf,
      searchHint: searchHint,
      emptyText: emptyText,
      hint: hint,
      minChars: minChars,
    ),
  );
}

class _SearchPickerDialog<T> extends StatefulWidget {
  const _SearchPickerDialog({
    required this.title,
    required this.load,
    required this.titleOf,
    required this.subtitleOf,
    required this.searchHint,
    required this.emptyText,
    required this.hint,
    required this.minChars,
  });

  final String title;
  final Future<List<T>> Function(String query) load;
  final String Function(T item) titleOf;
  final String? Function(T item)? subtitleOf;
  final String searchHint;
  final String emptyText;
  final String? hint;
  final int minChars;

  @override
  State<_SearchPickerDialog<T>> createState() => _SearchPickerDialogState<T>();
}

class _SearchPickerDialogState<T> extends State<_SearchPickerDialog<T>> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  bool _loading = false;
  List<T> _items = const [];

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String raw) async {
    final query = raw.trim();
    final seq = ++_seq;
    if (query.length < widget.minChars) {
      setState(() {
        _loading = false;
        _items = const [];
      });
      return;
    }
    setState(() => _loading = true);
    List<T> items;
    try {
      items = await widget.load(query);
    } catch (_) {
      items = const [];
    }
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooShort = _search.text.trim().length < widget.minChars;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _loading
                              ? 'Loading…'
                              : (tooShort && widget.hint != null)
                                  ? widget.hint!
                                  : widget.emptyText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        final subtitle = widget.subtitleOf?.call(item);
                        return ListTile(
                          dense: true,
                          title: Text(widget.titleOf(item),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: subtitle == null ? null : Text(subtitle),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
