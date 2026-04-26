import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

final _meProvider = FutureProvider.autoDispose<UserModel>((ref) async {
  final data = await ref.read(apiServiceProvider).getMe();
  return UserModel.fromJson(data);
});

// ─── Profile completion score ─────────────────────────────────────────────────

int _completionScore(UserModel u) {
  int score = 0;
  if (u.firstName.isNotEmpty) score++;
  if (u.lastName.isNotEmpty) score++;
  if (u.email.isNotEmpty) score++;
  if (u.phone != null && u.phone!.isNotEmpty) score++;
  if (u.bio != null && u.bio!.isNotEmpty) score++;
  if (u.avatarUrl != null && u.avatarUrl!.isNotEmpty) score++;
  return score; // max 6
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
    super.dispose();
  }

  void _populateEditors(UserModel u) {
    _firstNameCtrl.text = u.firstName;
    _lastNameCtrl.text = u.lastName;
    _phoneCtrl.text = u.phone ?? '';
    _bioCtrl.text = u.bio ?? '';
  }

  Future<void> _saveProfile() async {
    final payload = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
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
          const SnackBar(content: Text('Profile updated!')),
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
          const SnackBar(content: Text('Avatar updated!')),
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
    final pct = score / 6.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Avatar ─────────────────────────────────────────────────────────
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Text(
                        '${user.firstName[0]}${user.lastName[0]}'.toUpperCase(),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: saving ? null : onUploadAvatar,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
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
        ),
        const SizedBox(height: 12),

        // ── Name & role ────────────────────────────────────────────────────
        Text(
          user.fullName,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Center(child: _RoleBadge(role: user.role)),

        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            user.bio!,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
        ],

        // ── Profile completeness ───────────────────────────────────────────
        const SizedBox(height: 20),
        _ProfileCompletenessCard(score: score, pct: pct),

        const SizedBox(height: 20),
        const Divider(),

        // ── Role-specific tiles ────────────────────────────────────────────
        ..._roleTiles(context, user.role),

        const Divider(),
        _ProfileTile(
          icon: Icons.settings,
          label: 'Settings',
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.help_outline,
          label: 'Help & Support',
          onTap: () {},
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
    );
  }

  List<Widget> _roleTiles(BuildContext context, String role) {
    switch (role) {
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
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.star_border,
            label: 'My Reviews',
            onTap: () {},
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
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.business,
            label: 'My Organisation',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.subscriptions,
            label: 'Subscription',
            onTap: () {},
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
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.request_quote,
            label: 'My RFQs',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.subscriptions,
            label: 'Subscription',
            onTap: () {},
          ),
        ];
      default:
        return [
          _ProfileTile(
            icon: Icons.apartment,
            label: 'My Listings',
            onTap: () => context.go('/properties'),
          ),
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.star_border,
            label: 'My Reviews',
            onTap: () {},
          ),
        ];
    }
  }
}

// ─── Profile completeness card ────────────────────────────────────────────────

class _ProfileCompletenessCard extends StatelessWidget {
  const _ProfileCompletenessCard({required this.score, required this.pct});
  final int score;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final color = pct >= 0.8
        ? Colors.green[700]!
        : pct >= 0.5
            ? Colors.orange[700]!
            : Colors.red[600]!;

    final label = pct >= 1.0
        ? '🏆 Profile complete!'
        : pct >= 0.8
            ? '✨ Almost there!'
            : pct >= 0.5
                ? '📈 Keep going!'
                : '🚀 Get started!';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Profile Strength',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '$score/6 · ${(pct * 100).round()}%',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: pct),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
          if (pct < 1.0) ...[
            const SizedBox(height: 4),
            Text(
              _missingHint(score),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  String _missingHint(int score) {
    final hints = <String>[];
    // simple hints based on score
    if (score < 4) hints.add('Add phone number');
    if (score < 5) hints.add('Add a bio');
    if (score < 6) hints.add('Upload a profile photo');
    return hints.isNotEmpty ? 'Tip: ${hints.first}' : '';
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
    required this.saving,
    required this.onSave,
  });

  final UserModel user;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController bioCtrl;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 16),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
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
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _color().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color().withValues(alpha: 0.4)),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            color: _color(),
            fontWeight: FontWeight.w600,
            fontSize: 12,
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
