import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session_controller.dart';
import '../../auth/session_state.dart';
import '../../auth/user_role.dart';
import '../responsive.dart';
import '../theme.dart';
import 'logout_action.dart';
import 'theme_toggle_button.dart';
import 'vistar_assets.dart';
import 'vistar_background.dart';

/// Shell that wraps every authenticated screen. Renders a premium dark/light
/// sidebar + topbar on desktop & tablet, and a bottom-nav layout on mobile.
class AppScaffold extends ConsumerWidget {
  final Widget child;
  final int selectedIndex;
  final void Function(int index) onSelect;

  const AppScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final role = session is Authenticated ? session.role : null;
    final showReconciliation = role != UserRole.gateSecurity;
    final showReports = role != UserRole.gateSecurity;
    final showVendorMaster = role.isAdminOrWarehouseManager;
    final visibleIndexes = <int>[
      0,
      1,
      if (showReconciliation) 2,
      if (showReports) 3,
      if (showVendorMaster) 4,
    ];
    final navigationIndex =
        visibleIndexes.indexOf(selectedIndex).clamp(0, visibleIndexes.length - 1);

    final device = deviceClass(context);
    final desktop = device == DeviceClass.desktop || device == DeviceClass.wide;

    if (desktop) {
      return Scaffold(
        body: VistarBackground(
          child: SafeArea(
            child: Row(
              children: [
                _DesktopSidebar(
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                  showReconciliation: showReconciliation,
                  showReports: showReports,
                  showVendorMaster: showVendorMaster,
                  authed: session is Authenticated ? session : null,
                ),
                // Wrap the routed child in a fresh transparent Material so
                // the nested dashboard Scaffold + AppBar gets a clean
                // Material/hit-test context inside Expanded. Without this
                // wrap, Flutter web on desktop occasionally fails to route
                // pointer events through the nested-transparent-Scaffold
                // chain (Stack → Row → Expanded → transparent Scaffold).
                Expanded(
                  child: Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Tablet & mobile — bottom nav + page child.
    return Scaffold(
      extendBody: true,
      body: VistarBackground(child: SafeArea(bottom: false, child: child)),
      bottomNavigationBar: _MobileNavBar(
        selectedIndex: navigationIndex,
        showReconciliation: showReconciliation,
        showReports: showReports,
        showVendorMaster: showVendorMaster,
        onSelected: (i) => onSelect(visibleIndexes[i]),
      ),
    );
  }
}

class _MobileNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool showReconciliation;
  final bool showReports;
  final bool showVendorMaster;
  final ValueChanged<int> onSelected;

  const _MobileNavBar({
    required this.selectedIndex,
    required this.showReconciliation,
    required this.showReports,
    required this.showVendorMaster,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: VistarTokens.pink.withValues(alpha: 0.16),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping_rounded),
              label: 'Gate Entry',
            ),
            if (showReconciliation)
              const NavigationDestination(
                icon: Icon(Icons.rule_folder_outlined),
                selectedIcon: Icon(Icons.rule_folder_rounded),
                label: 'Reco',
              ),
            if (showReports)
              const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: 'Reports',
              ),
            if (showVendorMaster)
              const NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store_rounded),
                label: 'Vendors',
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int index) onSelect;
  final bool showReconciliation;
  final bool showReports;
  final bool showVendorMaster;
  final Authenticated? authed;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.showReconciliation,
    required this.showReports,
    required this.showVendorMaster,
    required this.authed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width >= Breakpoints.wide
        ? 268.0
        : 248.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDark
            ? VistarTokens.darkBg2.withValues(alpha: 0.85)
            : theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: VistarTokens.pink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    VistarAssets.sMark,
                    fit: BoxFit.contain,
                    cacheWidth: 132,
                    cacheHeight: 132,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.flash_on,
                      color: VistarTokens.pink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vistar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'Gate Reco',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              children: [
                const _SectionLabel(label: 'OPERATIONS'),
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
                _SidebarItem(
                  icon: Icons.local_shipping_outlined,
                  activeIcon: Icons.local_shipping_rounded,
                  label: 'Gate Entry',
                  isSelected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
                if (showReconciliation) ...[
                  const SizedBox(height: 22),
                  const _SectionLabel(label: 'RECONCILIATION'),
                  _SidebarItem(
                    icon: Icons.rule_folder_outlined,
                    activeIcon: Icons.rule_folder_rounded,
                    label: 'Exceptions',
                    isSelected: selectedIndex == 2,
                    onTap: () => onSelect(2),
                  ),
                ],
                if (showReports) ...[
                  const SizedBox(height: 22),
                  const _SectionLabel(label: 'ANALYTICS'),
                  _SidebarItem(
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart_rounded,
                    label: 'Reports',
                    isSelected: selectedIndex == 3,
                    onTap: () => onSelect(3),
                  ),
                ],
                if (showVendorMaster) ...[
                  const SizedBox(height: 22),
                  const _SectionLabel(label: 'ADMIN'),
                  _SidebarItem(
                    icon: Icons.store_outlined,
                    activeIcon: Icons.store_rounded,
                    label: 'Vendor Master',
                    isSelected: selectedIndex == 4,
                    onTap: () => onSelect(4),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          _UserFooter(authed: authed),
        ],
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  final Authenticated? authed;
  const _UserFooter({required this.authed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = authed?.fullName ?? 'Signed out';
    final roleLabel = authed?.role.label ?? '';
    final orgName = authed?.organization.name ?? '';
    final initials = _initials(fullName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: VistarTokens.ribbon,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (roleLabel.isNotEmpty)
                      Text(
                        roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (orgName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                orgName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Row(
            children: [
              ThemeToggleButton(),
              Spacer(),
              LogoutAction(),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '·';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6, top: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 10.5,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.65),
            ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = widget.isSelected;
    final activeBg = isDark
        ? VistarTokens.pink.withValues(alpha: 0.10)
        : VistarTokens.pink.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? activeBg
                  : (_hover
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: selected ? VistarTokens.ribbon : null,
                    color: selected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected ? widget.activeIcon : widget.icon,
                  color: selected
                      ? VistarTokens.pink
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
