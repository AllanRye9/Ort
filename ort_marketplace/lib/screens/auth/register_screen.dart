import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── shared fields ──────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // ── agent fields ────────────────────────────────────────────────────────────
  final _licenseNumberCtrl = TextEditingController();
  final _agencyNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String _role = 'user';
  bool _obscurePassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _agencyNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = <String, dynamic>{
      'role': _role,
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text,
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
    };

    if (_role == 'agent') {
      if (_licenseNumberCtrl.text.trim().isNotEmpty) {
        payload['license_number'] = _licenseNumberCtrl.text.trim();
      }
      if (_agencyNameCtrl.text.trim().isNotEmpty) {
        payload['agency_name'] = _agencyNameCtrl.text.trim();
      }
      if (_bioCtrl.text.trim().isNotEmpty) {
        payload['bio'] = _bioCtrl.text.trim();
      }
    }

    final ok = await ref.read(authProvider.notifier).register(payload);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Please sign in.')),
      );
      context.go('/login');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _nameValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.trim().length < 2) return 'Min 2 characters';
    if (v.trim().length > 100) return 'Max 100 characters';
    return null;
  }

  String? _emailValidator(String? v) =>
      v == null || !v.contains('@') ? 'Enter a valid email' : null;

  // ── Section builders ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contactFields() => [
        _sectionHeader('Contact Person', Icons.person_outline),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameCtrl,
                decoration: const InputDecoration(labelText: 'First Name'),
                maxLength: 100,
                validator: _nameValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastNameCtrl,
                decoration: const InputDecoration(labelText: 'Last Name'),
                maxLength: 100,
                validator: _nameValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: _emailValidator,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Phone (optional)',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
      ];

  List<Widget> _agentFields() => [
        _sectionHeader('Agent Details', Icons.badge_outlined),
        TextFormField(
          controller: _agencyNameCtrl,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Agency / Brokerage Name (optional)',
            prefixIcon: Icon(Icons.business_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _licenseNumberCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'License / Registration Number (optional)',
            prefixIcon: Icon(Icons.numbers_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bioCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Bio (optional)',
            prefixIcon: Icon(Icons.info_outline),
            alignLabelWithHint: true,
          ),
        ),
      ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isWide = context.isWide;

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Role selector ────────────────────────────────────────
          DropdownButtonFormField<String>(
            value: _role,
            decoration: const InputDecoration(
              labelText: 'Account Type',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'agent', child: Text('Agent')),
            ],
            onChanged: (v) => setState(() {
              _role = v!;
              _licenseNumberCtrl.clear();
              _agencyNameCtrl.clear();
              _bioCtrl.clear();
            }),
          ),

          // ── Contact fields (always shown) ────────────────────────
          ..._contactFields(),

          // ── Agent-specific fields ────────────────────────────────
          if (_role == 'agent') ..._agentFields(),

          // ── Password ─────────────────────────────────────────────
          _sectionHeader('Security', Icons.lock_outline),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePassword,
            maxLength: 72,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) return 'Min 8 characters';
              if (v.length > 72) return 'Max 72 characters';
              return null;
            },
          ),

          // ── Error banner ─────────────────────────────────────────
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Submit ───────────────────────────────────────────────
          ElevatedButton(
            onPressed: auth.isLoading ? null : _submit,
            child: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Account'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Already have an account? Sign In'),
          ),
          const SizedBox(height: 8),
          Text(
            'Companies & organisations register at ort.up.railway.app/medi',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );

    final animatedForm = FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: formContent),
    );

    // ── Wide layout: two-pane ──────────────────────────────────────────────
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // Left pane: gradient hero
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, Color(0xFF1B5E20)],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded,
                            size: 96, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          'Ort Marketplace',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Properties • Agriculture • Manufacturing',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Right pane: form
            Expanded(
              flex: 5,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create Account',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Join the Ort Marketplace today',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        animatedForm,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Narrow layout ─────────────────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: animatedForm,
        ),
      ),
    );
  }
}
