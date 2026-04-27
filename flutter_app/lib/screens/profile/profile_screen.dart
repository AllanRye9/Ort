import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

final _meProvider = FutureProvider.autoDispose<UserModel>((ref) async {
  final data = await ref.read(apiServiceProvider).getMe();
  return UserModel.fromJson(data);
});

// ─── Profile completion score (max 8) ─────────────────────────────────────────

int _completionScore(UserModel u) {
  int score = 0;
  if (u.firstName.isNotEmpty) score++;
  if (u.lastName.isNotEmpty) score++;
  if (u.email.isNotEmpty) score++;
  if (u.phone != null && u.phone!.isNotEmpty) score++;
  if (u.bio != null && u.bio!.isNotEmpty) score++;
  if (u.avatarUrl != null && u.avatarUrl!.isNotEmpty) score++;
  if (u.licenseNumber != null && u.licenseNumber!.isNotEmpty) score++;
  if (u.agencyName != null && u.agencyName!.isNotEmpty) score++;
  return score; // max 8
}

const int _maxScore = 8;
const int _xpPerPoint = 125;

// ─── XP levels ────────────────────────────────────────────────────────────────

String _levelLabel(int score) {
  if (score >= 8) return '🏆 Legend';
  if (score >= 6) return '⭐ Pro';
  if (score >= 4) return '🔥 Rising';
  if (score >= 2) return '🌱 Starter';
  return '👤 Newbie';
}

Color _levelColor(int score) {
  if (score >= 8) return const Color(0xFFFFD700);
  if (score >= 6) return AppTheme.primary;
  if (score >= 4) return Colors.orange;
  if (score >= 2) return Colors.blue;
  return Colors.grey;
}

// ─── Main screen ──────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  bool _editMode = false;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _licenseCtrl.dispose();
    _agencyCtrl.dispose();
    super.dispose();
  }

  void _populateEditors(UserModel u) {
    _firstNameCtrl.text = u.firstName;
    _lastNameCtrl.text = u.lastName;
    _phoneCtrl.text = u.phone ?? '';
    _bioCtrl.text = u.bio ?? '';
    _licenseCtrl.text = u.licenseNumber ?? '';
    _agencyCtrl.text = u.agencyName ?? '';
  }

  Future<void> _saveProfile() async {
    final payload = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      if (_licenseCtrl.text.trim().isNotEmpty)
        'license_number': _licenseCtrl.text.trim(),
      if (_agencyCtrl.text.trim().isNotEmpty)
        'agency_name': _agencyCtrl.text.trim(),
    };
    setState(() => _saving = true);
    try {
      await ref.read(apiServiceProvider).updateMe(payload);
      ref.invalidate(_meProvider);
      if (mounted) {
        setState(() {
          _saving = false;
          _editMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Profile updated! +$_xpPerPoint XP 🎉'),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final url = await ref.read(apiServiceProvider).uploadImage(
            bytes: bytes,
            filename: file.name,
            mimeType: mimeType,
          );
      await ref.read(apiServiceProvider).updateMe({'avatar_url': url});
      ref.invalidate(_meProvider);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated! 📸')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar upload failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final meAsync = ref.watch(_meProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (meAsync.hasValue && !_editMode)
            TextButton.icon(
              onPressed: () {
                _populateEditors(meAsync.value!);
                setState(() => _editMode = true);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          if (_editMode)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _editMode = false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: meAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) => _editMode
              ? _EditView(
                  user: user,
                  firstNameCtrl: _firstNameCtrl,
                  lastNameCtrl: _lastNameCtrl,
                  phoneCtrl: _phoneCtrl,
                  bioCtrl: _bioCtrl,
                  licenseCtrl: _licenseCtrl,
                  agencyCtrl: _agencyCtrl,
                  saving: _saving,
                  onSave: _saveProfile,
                )
              : _ReadView(
                  user: user,
                  auth: auth,
                  onUploadAvatar: _uploadAvatar,
                  saving: _saving,
                ),
        ),
      ),
    );
  }
}

// ─── Read-only view ───────────────────────────────────────────────────────────

class _ReadView extends StatelessWidget {
  const _ReadView({
    required this.user,
    required this.auth,
    required this.onUploadAvatar,
    required this.saving,
  });

  final UserModel user;
  final AuthState auth;
  final VoidCallback onUploadAvatar;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final score = _completionScore(user);
    final pct = score / _maxScore;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Gradient header ─────────────────────────────────────────────────
        _ProfileHeader(user: user, saving: saving, onUploadAvatar: onUploadAvatar),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── XP / Level card ────────────────────────────────────────────
              _XpLevelCard(score: score, pct: pct),
              const SizedBox(height: 16),

              // ── Info tiles ─────────────────────────────────────────────────
              _InfoSection(user: user),
              const SizedBox(height: 16),

              const Divider(),

              // ── Role-specific tiles ────────────────────────────────────────
              ..._roleTiles(context, user.role),

              const Divider(),
              _ProfileTile(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () => _showComingSoon(context, 'Settings'),
              ),
              _ProfileTile(
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () => _showHelpDialog(context),
              ),
              const Divider(),
              Consumer(
                builder: (ctx, ref, _) => _ProfileTile(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  iconColor: Colors.red,
                  labelColor: Colors.red,
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (ctx.mounted) ctx.go('/login');
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _roleTiles(BuildContext context, String role) {
    switch (role) {
      case 'admin':
        return [
          _ProfileTile(
            icon: Icons.admin_panel_settings_rounded,
            label: 'Admin Panel',
            iconColor: const Color(0xFF1B5E20),
            onTap: () => context.go('/admin'),
          ),
        ];
      case 'agent':
        return [
          _ProfileTile(
            icon: Icons.apartment,
            label: 'My Listings',
            onTap: () => context.go('/properties'),
          ),
          _ProfileTile(
            icon: Icons.people,
            label: 'My Clients',
            onTap: () => _showComingSoon(context, 'My Clients'),
          ),
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.star_border,
            label: 'My Reviews',
            onTap: () => _showComingSoon(context, 'My Reviews'),
          ),
        ];
      case 'company':
        return [
          _ProfileTile(
            icon: Icons.precision_manufacturing_outlined,
            label: 'My Products',
            onTap: () => context.go('/manufacturing'),
          ),
          _ProfileTile(
            icon: Icons.request_quote,
            label: 'My RFQs',
            onTap: () => _showComingSoon(context, 'My RFQs'),
          ),
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.business,
            label: 'My Organisation',
            onTap: () => _showComingSoon(context, 'My Organisation'),
          ),
          _ProfileTile(
            icon: Icons.subscriptions,
            label: 'Subscription',
            onTap: () => _showComingSoon(context, 'Subscription'),
          ),
        ];
      case 'organization':
        return [
          _ProfileTile(
            icon: Icons.grass,
            label: 'My Listings',
            onTap: () => context.go('/agriculture'),
          ),
          _ProfileTile(
            icon: Icons.business,
            label: 'My Organisation',
            onTap: () => _showComingSoon(context, 'My Organisation'),
          ),
          _ProfileTile(
            icon: Icons.request_quote,
            label: 'My RFQs',
            onTap: () => _showComingSoon(context, 'My RFQs'),
          ),
          _ProfileTile(
            icon: Icons.subscriptions,
            label: 'Subscription',
            onTap: () => _showComingSoon(context, 'Subscription'),
          ),
        ];
      case 'user':
        return [
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.request_quote,
            label: 'My RFQs',
            onTap: () => _showComingSoon(context, 'My RFQs'),
          ),
          _ProfileTile(
            icon: Icons.star_border,
            label: 'My Reviews',
            onTap: () => _showComingSoon(context, 'My Reviews'),
          ),
          _ProfileTile(
            icon: Icons.chat_bubble_outline,
            label: 'My Messages',
            onTap: () => context.go('/messages'),
          ),
        ];
      default:
        return [
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.star_border,
            label: 'My Reviews',
            onTap: () => _showComingSoon(context, 'My Reviews'),
          ),
        ];
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature – coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Contact us:'),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('support@ort.app'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.language_outlined, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('ort.up.railway.app'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient header with avatar ─────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.saving,
    required this.onUploadAvatar,
  });

  final UserModel user;
  final bool saving;
  final VoidCallback onUploadAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF388E3C)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.2),
                          child: Center(
                            child: Text(
                              '${user.firstName[0]}${user.lastName[0]}'
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: saving ? null : onUploadAvatar,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: saving
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _RoleBadge(role: user.role),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── XP level card ────────────────────────────────────────────────────────────

class _XpLevelCard extends StatelessWidget {
  const _XpLevelCard({required this.score, required this.pct});
  final int score;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(score);
    final label = _levelLabel(score);
    final xp = score * _xpPerPoint;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$xp XP',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: pct),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile $score/$_maxScore complete',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (pct < 1.0)
                Text(
                  _nextTip(score),
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _nextTip(int score) {
    if (score < 4) return '+ Add phone';
    if (score < 5) return '+ Add bio';
    if (score < 6) return '+ Add photo';
    if (score < 7) return '+ Add license';
    if (score < 8) return '+ Add agency';
    return '';
  }
}

// ─── Info section ─────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      if (user.phone != null && user.phone!.isNotEmpty)
        (Icons.phone_outlined, 'Phone', user.phone!),
      if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty)
        (Icons.badge_outlined, 'License', user.licenseNumber!),
      if (user.agencyName != null && user.agencyName!.isNotEmpty)
        (Icons.business_outlined, 'Agency / Company', user.agencyName!),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final (icon, label, value) = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 18,
                        color: AppTheme.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500])),
                          Text(value,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (e.key < items.length - 1)
                const Divider(height: 1, indent: 46),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Edit view ────────────────────────────────────────────────────────────────

class _EditView extends StatelessWidget {
  const _EditView({
    required this.user,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.bioCtrl,
    required this.licenseCtrl,
    required this.agencyCtrl,
    required this.saving,
    required this.onSave,
  });

  final UserModel user;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController bioCtrl;
  final TextEditingController licenseCtrl;
  final TextEditingController agencyCtrl;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Basic Info'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: firstNameCtrl,
                  maxLength: 100,
                  decoration:
                      const InputDecoration(labelText: 'First Name'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: lastNameCtrl,
                  maxLength: 100,
                  decoration:
                      const InputDecoration(labelText: 'Last Name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: bioCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Bio (optional)',
              prefixIcon: Icon(Icons.info_outline),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Professional Info'),
          const SizedBox(height: 12),
          TextFormField(
            controller: licenseCtrl,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'License / Registration Number (optional)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: agencyCtrl,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Agency / Company Name (optional)',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(saving ? 'Saving…' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
            letterSpacing: 0.5),
      );
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  Color _color() {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'company':
        return Colors.blue;
      case 'organization':
        return Colors.purple;
      case 'agent':
        return Colors.teal;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.5), width: 1),
        ),
        child: Text(
          role.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label,
            style:
                labelColor != null ? TextStyle(color: labelColor) : null),
        trailing:
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        onTap: onTap,
      );
}
