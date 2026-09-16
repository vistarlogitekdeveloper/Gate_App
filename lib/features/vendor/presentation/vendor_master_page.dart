import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/auth/session_state.dart';
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
              subtitle: 'Search, add, update or remove vendor master records.',
              trailing: mob
                  ? null
                  : RibbonButton(
                      label: 'Add Vendor',
                      icon: Icons.add_circle_outline,
                      onPressed: _openCreate,
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
                          );
                        },
                      )
                    : _VendorTable(
                        vendors: result.vendors,
                        onEdit: _openEdit,
                        onDelete: _confirmDelete,
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

  const _VendorTable({
    required this.vendors,
    required this.onEdit,
    required this.onDelete,
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

  const _VendorCard({
    required this.vendor,
    required this.onEdit,
    required this.onDelete,
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
