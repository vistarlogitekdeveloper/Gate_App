import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets/ribbon.dart';
import '../../../core/ui/widgets/theme_toggle_button.dart';
import '../../../core/ui/widgets/vistar_assets.dart';
import '../../../core/ui/widgets/vistar_background.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _organizationCodeCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _organizationCodeCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _normalizeOrganizationCode() {
    final normalized = _organizationCodeCtrl.text.trim().toUpperCase();
    if (_organizationCodeCtrl.text != normalized) {
      _organizationCodeCtrl.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
  }

  Future<void> _login() async {
    final organizationCode = _organizationCodeCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (organizationCode.isEmpty) {
      _showSnack('Organization code is required.');
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{2,32}$').hasMatch(organizationCode)) {
      _showSnack(
        'Organization code must be 2-32 characters and use only letters, numbers, _ or -.',
      );
      return;
    }
    if (username.isEmpty || password.isEmpty) {
      _showSnack('Enter email or username and password.');
      return;
    }

    setState(() => _isLoading = true);
    String? errorMessage;
    try {
      errorMessage = await ref.read(sessionControllerProvider.notifier).login(
            organizationCode: organizationCode,
            identifier: username,
            password: password,
            rememberMe: _rememberMe,
          );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to sign in right now. Please try again.');
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    if (errorMessage != null) _showSnack(errorMessage);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final wide = !isMobile(context) &&
        MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

    return Scaffold(
      body: VistarBackground(
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: 8,
                right: 8,
                child: ThemeToggleButton(),
              ),
              if (wide)
                _DesktopSplit(
                  formKey: _formKey,
                  organizationCodeCtrl: _organizationCodeCtrl,
                  usernameCtrl: _usernameCtrl,
                  passwordCtrl: _passwordCtrl,
                  isLoading: _isLoading,
                  obscurePassword: _obscurePassword,
                  rememberMe: _rememberMe,
                  onToggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onToggleRemember: (v) =>
                      setState(() => _rememberMe = v ?? false),
                  onLogin: _login,
                  onNormalizeOrg: _normalizeOrganizationCode,
                )
              else
                _MobileForm(
                  formKey: _formKey,
                  organizationCodeCtrl: _organizationCodeCtrl,
                  usernameCtrl: _usernameCtrl,
                  passwordCtrl: _passwordCtrl,
                  isLoading: _isLoading,
                  obscurePassword: _obscurePassword,
                  rememberMe: _rememberMe,
                  onToggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onToggleRemember: (v) =>
                      setState(() => _rememberMe = v ?? false),
                  onLogin: _login,
                  onNormalizeOrg: _normalizeOrganizationCode,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSplit extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController organizationCodeCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool isLoading;
  final bool obscurePassword;
  final bool rememberMe;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onLogin;
  final VoidCallback onNormalizeOrg;

  const _DesktopSplit({
    required this.formKey,
    required this.organizationCodeCtrl,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.isLoading,
    required this.obscurePassword,
    required this.rememberMe,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onLogin,
    required this.onNormalizeOrg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left art panel
        Expanded(
          flex: 105,
          child: _ArtPanel(),
        ),
        // Right form panel
        Expanded(
          flex: 95,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _LoginForm(
                  formKey: formKey,
                  organizationCodeCtrl: organizationCodeCtrl,
                  usernameCtrl: usernameCtrl,
                  passwordCtrl: passwordCtrl,
                  isLoading: isLoading,
                  obscurePassword: obscurePassword,
                  rememberMe: rememberMe,
                  onToggleObscure: onToggleObscure,
                  onToggleRemember: onToggleRemember,
                  onLogin: onLogin,
                  onNormalizeOrg: onNormalizeOrg,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController organizationCodeCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool isLoading;
  final bool obscurePassword;
  final bool rememberMe;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onLogin;
  final VoidCallback onNormalizeOrg;

  const _MobileForm({
    required this.formKey,
    required this.organizationCodeCtrl,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.isLoading,
    required this.obscurePassword,
    required this.rememberMe,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onLogin,
    required this.onNormalizeOrg,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mini brand block
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: VistarTokens.pink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    VistarAssets.sMark,
                    fit: BoxFit.contain,
                    cacheWidth: 168,
                    cacheHeight: 168,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.flash_on, color: VistarTokens.pink),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Image.asset(
                  VistarAssets.wordmark,
                  height: 40,
                  fit: BoxFit.contain,
                  cacheHeight: 120,
                  errorBuilder: (_, __, ___) => Text(
                    'Vistar',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _LoginForm(
                formKey: formKey,
                organizationCodeCtrl: organizationCodeCtrl,
                usernameCtrl: usernameCtrl,
                passwordCtrl: passwordCtrl,
                isLoading: isLoading,
                obscurePassword: obscurePassword,
                rememberMe: rememberMe,
                onToggleObscure: onToggleObscure,
                onToggleRemember: onToggleRemember,
                onLogin: onLogin,
                onNormalizeOrg: onNormalizeOrg,
                isCompact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: Stack(
        children: [
          // Giant rotated faint S
          Positioned(
            right: -120,
            top: -120,
            bottom: -120,
            width: 760,
            child: IgnorePointer(
              child: Opacity(
                opacity:
                    theme.brightness == Brightness.dark ? 0.16 : 0.10,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Image.asset(
                    VistarAssets.sMark,
                    fit: BoxFit.contain,
                    cacheWidth: 760,
                    cacheHeight: 760,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wordmark
                Image.asset(
                  VistarAssets.wordmark,
                  height: 50,
                  fit: BoxFit.contain,
                  cacheHeight: 150,
                  errorBuilder: (_, __, ___) => Text(
                    'Vistar',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                // Pitch headline
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Gate to GRN.\n',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          height: 1.05,
                        ),
                      ),
                      WidgetSpan(
                        baseline: TextBaseline.alphabetic,
                        alignment: PlaceholderAlignment.baseline,
                        child: RibbonText(
                          'Reconciled.',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    'A premium operations console for your warehouse — track gate movements, post GRNs, and resolve exceptions in real time.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                // Stat row
                const Row(
                  children: [
                    _StatBlock(value: '99.8%', label: 'Reco accuracy'),
                    SizedBox(width: 28),
                    _StatBlock(value: '<2m', label: 'Avg gate TAT'),
                    SizedBox(width: 28),
                    _StatBlock(value: '24×7', label: 'Live sync'),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RibbonText(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController organizationCodeCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool isLoading;
  final bool obscurePassword;
  final bool rememberMe;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onLogin;
  final VoidCallback onNormalizeOrg;
  final bool isCompact;

  const _LoginForm({
    required this.formKey,
    required this.organizationCodeCtrl,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.isLoading,
    required this.obscurePassword,
    required this.rememberMe,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onLogin,
    required this.onNormalizeOrg,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCompact) ...[
            Text(
              'Sign in',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Welcome back — pick up where you left off.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 26),
          ] else ...[
            Text(
              'Sign in',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: organizationCodeCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(32),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
            ],
            onEditingComplete: onNormalizeOrg,
            decoration: const InputDecoration(
              labelText: 'Organization Code',
              hintText: 'e.g. DEFAULT',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'Email or Username',
              hintText: 'e.g. admin@warehouse.local',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordCtrl,
            obscureText: obscurePassword,
            onSubmitted: (_) => isLoading ? null : onLogin(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                tooltip: obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: isLoading ? null : onToggleRemember,
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isLoading ? null : () => onToggleRemember(!rememberMe),
                  child: Text(
                    'Remember me for 30 days',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RibbonButton(
            label: isLoading ? 'Signing in…' : 'Continue',
            icon: isLoading ? null : Icons.lock_open_rounded,
            loading: isLoading,
            fullWidth: true,
            onPressed: isLoading ? null : onLogin,
          ),
          const SizedBox(height: 12),
          Text(
            'By signing in you agree to your organization’s usage policy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
