import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/ui/widgets/progress_dialog.dart';
import '../../gate_entry/presentation/widgets/search_picker_dialog.dart';
import '../data/vendor_repository_impl.dart';
import '../domain/models/vendor_po_material.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/section_header.dart';
import '../../../core/ui/widgets/skeleton_loader.dart';
import '../../../core/ui/widgets/theme_toggle_button.dart';
import 'controllers/vendor_providers.dart';
import '../domain/models/vendor.dart';
import 'widgets/vendor_form_dialog.dart';

class VendorMasterPage extends ConsumerStatefulWidget {
  const VendorMasterPage({super.key});

  @override
  ConsumerState<VendorMasterPage> createState() => _VendorMasterPageState();
}

class _VendorMasterPageState extends ConsumerState<VendorMasterPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Sync controller from initial query (e.g., when returning to the page).
    final initialQuery = ref.read(vendorListQueryProvider).query ?? '';
    _searchCtrl.text = initialQuery;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(vendorListQueryProvider.notifier).update(
            (q) => q.copyWith(query: value.trim().isEmpty ? null : value.trim(),
                offset: 0),
          );
    });
  }

  void _setVendorType(VendorType? type) {
    ref.read(vendorListQueryProvider.notifier).update(
          (q) => q.copyWith(vendorType: type, offset: 0),
        );
  }

  void _setActiveFilter(bool? value) {
    ref.read(vendorListQueryProvider.notifier).update(
          (q) => q.copyWith(isActive: value, offset: 0),
        );
  }

  Future<void> _openCreate() async {
    final created = await showVendorFormDialog(context);
    if (created != null && mounted) {
      ref.invalidate(vendorListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            'Vendor "${created.vendorName}" created successfully',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _openEdit(Vendor vendor) async {
    final updated =
        await showVendorFormDialog(context, existing: vendor);
    if (updated != null && mounted) {
      ref.invalidate(vendorListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            'Vendor "${updated.vendorName}" updated successfully',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(Vendor vendor) async {
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => _DeleteVendorDialog(vendor: vendor),
    );
    if (choice == null || !mounted) return;

    final controller = ref.read(vendorActionControllerProvider.notifier);
    final ok = await controller.delete(vendor.id, hard: choice == _DeleteChoice.hard);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(vendorListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(choice == _DeleteChoice.hard
              ? 'Vendor "${vendor.vendorName}" permanently removed.'
              : 'Vendor "${vendor.vendorName}" deactivated.'),
        ),
      );
    } else {
      final lastErr = ref.read(vendorActionControllerProvider.notifier).lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(
            lastErr != null
                ? lastErr.toString().replaceAll('Exception: ', '')
                : 'Failed to delete vendor.',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
        ),
      );
    }
  }

  bool get _isAdmin {
    final session = ref.read(sessionControllerProvider);
    return session is Authenticated && session.role == UserRole.admin;
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Theme.of(context).colorScheme.error,
      content: Text(
        e.toString().replaceFirst('Exception: ', ''),
        style: TextStyle(color: Theme.of(context).colorScheme.onError),
      ),
    ));
  }

  /// Replace the purchase vendors and their POs / materials from the client's
  /// SAP export (admin only). Always previews first; nothing is written until
  /// the admin confirms a file without errors.
  Future<void> _openImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showError('Could not read the selected file.');
      return;
    }
    final repo = ref.read(vendorRepositoryProvider);
    Future<VendorImportSummary> send(bool dryRun) => repo.importVendorMaster(
          fileName: file.name,
          bytes: bytes,
          dryRun: dryRun,
        );

    VendorImportSummary preview;
    try {
      preview = await runWithProgressDialog(context, () => send(true),
          label: 'Reading the file...');
    } catch (e) {
      _showError(e);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ImportPreviewDialog(summary: preview, fileName: file.name),
    );
    if (confirmed != true || !mounted) return;

    try {
      final done = await runWithProgressDialog(context, () => send(false),
          label: 'Replacing the vendor master...');
      if (!mounted) return;
      ref.invalidate(vendorListProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Text(
          'Vendor master replaced: ${done.vendors} vendors, '
          '${done.purchaseOrders} POs, ${done.materials} materials'
          '${done.deleted > 0 ? '; ${done.deleted} old vendors deleted' : ''}.',
          style: const TextStyle(color: Colors.white),
        ),
      ));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showVendorPos(Vendor vendor) async {
    List<VendorPoMaterial> rows;
    try {
      rows = await runWithProgressDialog(
        context,
        () => ref.read(vendorRepositoryProvider).getVendorPurchaseOrders(vendor.id),
        label: 'Loading POs...',
      );
    } catch (e) {
      _showError(e);
      return;
    }
    if (!mounted) return;
    await showSearchPicker<VendorPoMaterial>(
      context,
      title: '${vendor.vendorName} (${vendor.vendorCode})',
      load: (q) async {
        final ql = q.toLowerCase();
        return rows
            .where((r) =>
                ql.isEmpty ||
                r.poNumber.toLowerCase().contains(ql) ||
                (r.materialCode ?? '').toLowerCase().contains(ql))
            .toList();
      },
      titleOf: (r) => 'PO ${r.poNumber}',
      subtitleOf: (r) =>
          r.materialCode == null ? null : 'Material ${r.materialCode}',
      searchHint: 'Search PO or material',
      emptyText: rows.isEmpty
          ? 'No purchase orders in the vendor master for this vendor.'
          : 'No PO or material matches.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(vendorListQueryProvider);
    final vendorsAsync = ref.watch(vendorListProvider);
    final mob = isMobile(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            RibbonAccentBar(height: 22),
            SizedBox(width: 10),
            Flexible(child: Text('Vendor Master')),
          ],
        ),
        actions: [
          if (mob && _isAdmin)
            IconButton(
              tooltip: 'Import from Excel',
              onPressed: _openImport,
              icon: const Icon(Icons.upload_file_rounded),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(vendorListProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: mob
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add Vendor'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vendorListProvider);
          await ref.read(vendorListProvider.future).catchError((_) {
            return const VendorListResult(
              vendors: [],
              limit: 50,
              offset: 0,
              count: 0,
            );
          });
        },
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: mob ? 16 : 24, vertical: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Manage Vendors',
              subtitle: 'Search, add, update or remove vendor master records, '
                  'with each vendor\'s purchase orders and materials.',
              trailing: mob
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAdmin) ...[
                          OutlinedButton.icon(
                            onPressed: _openImport,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Import from Excel'),
                          ),
                          const SizedBox(width: 12),
                        ],
                        RibbonButton(
                          label: 'Add Vendor',
                          icon: Icons.add_circle_outline,
                          onPressed: _openCreate,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _FilterBar(
              searchCtrl: _searchCtrl,
              onSearchChanged: _onSearchChanged,
              vendorType: query.vendorType,
              isActive: query.isActive,
              onVendorTypeChanged: _setVendorType,
              onActiveChanged: _setActiveFilter,
              compact: mob,
            ),
            const SizedBox(height: 16),
            vendorsAsync.when(
              loading: () => const Column(
                children: [
                  SkeletonLoader(width: double.infinity, height: 64),
                  SizedBox(height: 10),
                  SkeletonLoader(width: double.infinity, height: 64),
                  SizedBox(height: 10),
                  SkeletonLoader(width: double.infinity, height: 64),
                ],
              ),
              error: (e, _) => _ErrorBanner(message: e.toString()),
              data: (result) {
                if (result.vendors.isEmpty) {
                  final hasFilter = (query.query?.trim().isNotEmpty ?? false) ||
                      query.vendorType != null ||
                      query.isActive != null;
                  return _EmptyState(
                    hasActiveFilter: hasFilter,
                    onRetry: () => ref.invalidate(vendorListProvider),
                  );
                }
                return mob
                    // Virtualised: ListView.builder only materialises cards
                    // visible on screen. The old Column.map.toList() built
                    // every card at once, which froze the page when the
                    // vendor list was large.
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: result.vendors.length,
                        itemBuilder: (context, index) {
                          final v = result.vendors[index];
                          return _VendorCard(
                            vendor: v,
                            onEdit: () => _openEdit(v),
                            onDelete: () => _confirmDelete(v),
                            onShowPos: () => _showVendorPos(v),
                          );
                        },
                      )
                    : _VendorTable(
                        vendors: result.vendors,
                        onEdit: _openEdit,
                        onDelete: _confirmDelete,
                        onShowPos: _showVendorPos,
                      );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VendorType? vendorType;
  final bool? isActive;
  final ValueChanged<VendorType?> onVendorTypeChanged;
  final ValueChanged<bool?> onActiveChanged;
  final bool compact;

  const _FilterBar({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.vendorType,
    required this.isActive,
    required this.onVendorTypeChanged,
    required this.onActiveChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchField = TextField(
      controller: searchCtrl,
      onChanged: onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by vendor name or code',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchCtrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: () {
                  searchCtrl.clear();
                  onSearchChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );

    final typeDropdown = DropdownButtonFormField<VendorType?>(
      initialValue: vendorType,
      decoration: const InputDecoration(
        labelText: 'Type',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: <DropdownMenuItem<VendorType?>>[
        const DropdownMenuItem(value: null, child: Text('All Types')),
        ...VendorType.values.map(
          (t) => DropdownMenuItem(value: t, child: Text(t.label)),
        ),
      ],
      onChanged: onVendorTypeChanged,
    );

    final statusDropdown = DropdownButtonFormField<_StatusFilter>(
      initialValue: _statusFilterFromBool(isActive),
      decoration: const InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.toggle_on_outlined),
      ),
      items: const [
        DropdownMenuItem(value: _StatusFilter.all, child: Text('All Status')),
        DropdownMenuItem(value: _StatusFilter.active, child: Text('Active')),
        DropdownMenuItem(
            value: _StatusFilter.inactive, child: Text('Inactive')),
      ],
      onChanged: (v) {
        switch (v) {
          case _StatusFilter.active:
            onActiveChanged(true);
            break;
          case _StatusFilter.inactive:
            onActiveChanged(false);
            break;
          case _StatusFilter.all:
          case null:
            onActiveChanged(null);
            break;
        }
      },
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: compact
            ? Column(
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  typeDropdown,
                  const SizedBox(height: 12),
                  statusDropdown,
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: typeDropdown),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: statusDropdown),
                ],
              ),
      ),
    );
  }
}

enum _StatusFilter { all, active, inactive }

_StatusFilter _statusFilterFromBool(bool? v) {
  if (v == null) return _StatusFilter.all;
  return v ? _StatusFilter.active : _StatusFilter.inactive;
}

class _VendorTable extends StatelessWidget {
  final List<Vendor> vendors;
  final void Function(Vendor vendor) onEdit;
  final void Function(Vendor vendor) onDelete;
  final void Function(Vendor vendor) onShowPos;

  const _VendorTable({
    required this.vendors,
    required this.onEdit,
    required this.onDelete,
    required this.onShowPos,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        // A DataTable inside a horizontal scroll view sizes itself to its
        // intrinsic content width, which left ~325px of dead space to the
        // right of the card on a wide window. Giving it the card width as a
        // MINIMUM fills the space while still scrolling when the columns
        // genuinely need more room than is available.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 16,
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Vendor Code')),
              DataColumn(label: Text('Vendor Name')),
              DataColumn(label: Text('Purchase Orders'), numeric: true),
              DataColumn(label: Text('Materials'), numeric: true),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Updated')),
              DataColumn(label: Text('Actions')),
            ],
            rows: vendors.map((v) {
              return DataRow(cells: [
                DataCell(Text(
                  v.vendorCode,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )),
                DataCell(SizedBox(
                  width: 280,
                  child: Text(
                    v.vendorName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(
                  _CountLink(count: v.purchaseOrderCount),
                  onTap: v.purchaseOrderCount > 0 ? () => onShowPos(v) : null,
                ),
                DataCell(
                  _CountLink(count: v.materialCount),
                  onTap: v.materialCount > 0 ? () => onShowPos(v) : null,
                ),
                DataCell(_TypeChip(type: v.vendorType)),
                DataCell(_StatusChip(active: v.isActive)),
                DataCell(Text(_formatDate(v.updatedAt ?? v.createdAt))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(v),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () => onDelete(v),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShowPos;

  const _VendorCard({
    required this.vendor,
    required this.onEdit,
    required this.onDelete,
    required this.onShowPos,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vendor.vendorName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(active: vendor.isActive),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.qr_code_2,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  vendor.vendorCode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 14),
                _TypeChip(type: vendor.vendorType),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: vendor.purchaseOrderCount > 0 ? onShowPos : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${vendor.purchaseOrderCount} PO${vendor.purchaseOrderCount == 1 ? '' : 's'}'
                  '  ·  ${vendor.materialCount} material${vendor.materialCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: vendor.purchaseOrderCount > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    decoration: vendor.purchaseOrderCount > 0
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updated: ${_formatDate(vendor.updatedAt ?? vendor.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A count that opens the vendor's PO list when there is something to show.
class _CountLink extends StatelessWidget {
  final int count;

  const _CountLink({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (count == 0) {
      return Text('0',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
    }
    return Text(
      '$count',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

/// What an import will do; "Replace" only when the file has no row errors.
class _ImportPreviewDialog extends StatelessWidget {
  final VendorImportSummary summary;
  final String fileName;

  const _ImportPreviewDialog({required this.summary, required this.fileName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final s = summary;
    final hasErrors = s.errorCount > 0;

    Widget line(String label, int value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text('$value',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        );

    return AlertDialog(
      title: Text(hasErrors ? 'File has errors' : 'Replace vendor master?'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              line('Suppliers in the file', s.vendors),
              line('Purchase orders', s.purchaseOrders),
              line('Materials', s.materials),
              const Divider(height: 20),
              line('New suppliers', s.added),
              line('Name changed', s.renamed),
              line('Switched back on', s.reactivated),
              line('Unchanged', s.unchanged),
              line('Deleted (not in the file)', s.deleted,
                  color: s.deleted > 0 ? error : null),
              if (s.deletedVendors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final v in s.deletedVendors)
                        Text('${v.vendorCode}  ${v.vendorName}',
                            style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'The purchase order and material list is replaced by the '
                'file. Sold-to vendors are not affected. Old gate entries keep '
                'their vendor, PO and material.',
                style: theme.textTheme.bodySmall,
              ),
              if (s.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final w in s.warnings)
                  Text('• $w',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.orange.shade800)),
              ],
              if (hasErrors) ...[
                const SizedBox(height: 12),
                Text(
                  '${s.errorCount} row${s.errorCount == 1 ? '' : 's'} need fixing '
                  'before anything can be imported:',
                  style: TextStyle(color: error, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final e in s.errors)
                  Text('Row ${e.row}: ${e.message}',
                      style: theme.textTheme.bodySmall?.copyWith(color: error)),
                if (s.errorCount > s.errors.length)
                  Text('…and ${s.errorCount - s.errors.length} more.',
                      style: theme.textTheme.bodySmall?.copyWith(color: error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(hasErrors ? 'Close' : 'Cancel'),
        ),
        if (!hasErrors)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: s.deleted > 0 ? error : null,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.published_with_changes_rounded, size: 18),
            label: const Text('Replace vendor master'),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final VendorType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == VendorType.purchase ? Colors.indigo : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.grey;
    final label = active ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  final bool hasActiveFilter;
  final VoidCallback onRetry;

  const _EmptyState({
    required this.hasActiveFilter,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    // When no filter is active and the server still returned zero rows, this
    // is almost always a backend / data / scoping problem — surface the
    // organization code so the user can tell the admin exactly which tenant
    // has no vendors, instead of just staring at a blank screen.
    final orgCode = session is Authenticated ? session.organization.code : null;

    final title = hasActiveFilter
        ? 'No vendors match your filters'
        : 'No vendors available';
    final subtitle = hasActiveFilter
        ? 'Try clearing the search / filter chips above, or add a new vendor.'
        : orgCode != null && orgCode.isNotEmpty
            ? 'The server returned zero vendors for organization "$orgCode". '
                'This usually means the vendor master has not been synced or '
                'the tenant has no vendors yet. Contact your admin, or retry '
                'in case of a transient sync delay.'
            : 'The server returned zero vendors. Contact your admin to verify '
                'the vendor master has been synced.';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              hasActiveFilter ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.replaceAll('Exception: ', ''),
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DeleteChoice { soft, hard }

class _DeleteVendorDialog extends StatefulWidget {
  final Vendor vendor;
  const _DeleteVendorDialog({required this.vendor});

  @override
  State<_DeleteVendorDialog> createState() => _DeleteVendorDialogState();
}

class _DeleteVendorDialogState extends State<_DeleteVendorDialog> {
  bool _hard = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: theme.colorScheme.error),
          const SizedBox(width: 10),
          const Expanded(child: Text('Delete Vendor')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Are you sure you want to delete '),
                TextSpan(
                  text: '"${widget.vendor.vendorName}"',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _hard,
            onChanged: (v) => setState(() => _hard = v),
            title: Text(
              'Permanently delete (hard delete)',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _hard
                  ? 'The row will be removed from the database. This cannot be undone.'
                  : 'The vendor will be deactivated (soft delete) and can be restored later.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor:
                theme.colorScheme.error.withValues(alpha: 0.15),
            foregroundColor: theme.colorScheme.error,
          ),
          onPressed: () => Navigator.of(context)
              .pop(_hard ? _DeleteChoice.hard : _DeleteChoice.soft),
          child: Text(_hard ? 'Delete Permanently' : 'Deactivate'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  return DateFormat('MMM dd, yyyy').format(d.toLocal());
}
