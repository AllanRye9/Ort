import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
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

  // ── company / organisation fields ──────────────────────────────────────────
  final _companyNameCtrl = TextEditingController();
  final _regNumberCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _businessEmailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  String _role = 'user';
  String _orgType = 'ngo';
  bool _obscurePassword = true;

  static const _orgTypes = [
    DropdownMenuItem(value: 'ngo', child: Text('NGO (Non-Governmental Org)')),
    DropdownMenuItem(value: 'government', child: Text('Government Body')),
    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
    DropdownMenuItem(value: 'sme', child: Text('SME (Small/Medium Enterprise)')),
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _agencyNameCtrl.dispose();
    _bioCtrl.dispose();
    _companyNameCtrl.dispose();
    _regNumberCtrl.dispose();
    _businessPhoneCtrl.dispose();
    _businessEmailCtrl.dispose();
    _addressCtrl.dispose();
    _countryCtrl.dispose();
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
    } else if (_role == 'company') {
      payload['company_name'] = _companyNameCtrl.text.trim();
      if (_regNumberCtrl.text.trim().isNotEmpty) {
        payload['registration_number'] = _regNumberCtrl.text.trim();
      }
      if (_businessPhoneCtrl.text.trim().isNotEmpty) {
        payload['business_phone'] = _businessPhoneCtrl.text.trim();
      }
      if (_businessEmailCtrl.text.trim().isNotEmpty) {
        payload['business_email'] = _businessEmailCtrl.text.trim();
      }
      if (_addressCtrl.text.trim().isNotEmpty) {
        payload['address'] = _addressCtrl.text.trim();
      }
      if (_countryCtrl.text.trim().isNotEmpty) {
        payload['country'] = _countryCtrl.text.trim();
      }
    } else if (_role == 'organization') {
      payload['company_name'] = _companyNameCtrl.text.trim();
      payload['org_type'] = _orgType;
      if (_businessPhoneCtrl.text.trim().isNotEmpty) {
        payload['business_phone'] = _businessPhoneCtrl.text.trim();
      }
      if (_businessEmailCtrl.text.trim().isNotEmpty) {
        payload['business_email'] = _businessEmailCtrl.text.trim();
      }
      if (_addressCtrl.text.trim().isNotEmpty) {
        payload['address'] = _addressCtrl.text.trim();
      }
      if (_countryCtrl.text.trim().isNotEmpty) {
        payload['country'] = _countryCtrl.text.trim();
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

  String? _requiredValidator(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  String? _nameValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.trim().length < 2) return 'Min 2 characters';
    if (v.trim().length > 100) return 'Max 100 characters';
    return null;
  }

  String? _emailValidator(String? v) =>
      v == null || !v.contains('@') ? 'Enter a valid email' : null;

  /// Optional email – only validates format when a value is provided.
  String? _optionalEmailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return v.contains('@') ? null : 'Enter a valid email';
  }

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

  /// Fields always visible regardless of role.
  List<Widget> _contactFields() => [
        _sectionHeader('Contact Person', Icons.person_outline),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameCtrl,
                decoration:
                    const InputDecoration(labelText: 'First Name'),
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

  /// Extra fields shown only for agent accounts.
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

  /// Extra fields shown only for company accounts.
  List<Widget> _companyFields() => [
        _sectionHeader('Company Details', Icons.business_outlined),
        TextFormField(
          controller: _companyNameCtrl,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Company Name *',
            prefixIcon: Icon(Icons.business),
          ),
          validator: _requiredValidator,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _regNumberCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Business Registration Number (optional)',
            prefixIcon: Icon(Icons.numbers_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessPhoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Business Phone (optional)',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Business Email (optional)',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: _optionalEmailValidator,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressCtrl,
          decoration: const InputDecoration(
            labelText: 'Business Address (optional)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _countryCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Country (optional)',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
      ];

  /// Extra fields shown only for organisation accounts.
  List<Widget> _organizationFields() => [
        _sectionHeader('Organisation Details', Icons.groups_outlined),
        TextFormField(
          controller: _companyNameCtrl,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Organisation Name *',
            prefixIcon: Icon(Icons.groups),
          ),
          validator: _requiredValidator,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _orgType,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Organisation Type *',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: _orgTypes,
          onChanged: (v) => setState(() => _orgType = v!),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessPhoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Organisation Phone (optional)',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Organisation Email (optional)',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: _optionalEmailValidator,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressCtrl,
          decoration: const InputDecoration(
            labelText: 'Organisation Address (optional)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _countryCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Country (optional)',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
      ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Role selector ──────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Account Type',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Regular User (Buyer)')),
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                    DropdownMenuItem(value: 'company', child: Text('Company')),
                    DropdownMenuItem(
                        value: 'organization', child: Text('Organisation')),
                  ],
                  onChanged: (v) => setState(() {
                    _role = v!;
                    // Clear role-specific fields when switching role to avoid
                    // stale validators triggering on hidden fields.
                    _licenseNumberCtrl.clear();
                    _agencyNameCtrl.clear();
                    _bioCtrl.clear();
                    _companyNameCtrl.clear();
                    _regNumberCtrl.clear();
                    _businessPhoneCtrl.clear();
                    _businessEmailCtrl.clear();
                    _addressCtrl.clear();
                    _countryCtrl.clear();
                  }),
                ),

                // ── Contact fields (always shown) ──────────────────────────
                ..._contactFields(),

                // ── Role-specific fields ───────────────────────────────────
                if (_role == 'agent') ..._agentFields(),
                if (_role == 'company') ..._companyFields(),
                if (_role == 'organization') ..._organizationFields(),

                // ── Password ───────────────────────────────────────────────
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
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Min 8 characters';
                    if (v.length > 72) return 'Max 72 characters';
                    return null;
                  },
                ),

                // ── Error banner ───────────────────────────────────────────
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
                        color:
                            Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 18),
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

                // ── Submit ─────────────────────────────────────────────────
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
