import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';
import '../../services/sound_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _soundEnabled = true;
  bool _ambientEnabled = false;
  double _volume = 0.7;

  @override
  void initState() {
    super.initState();
    final s = SoundService.instance;
    _soundEnabled = s.soundEnabled;
    _ambientEnabled = s.ambientEnabled;
    _volume = s.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Sound & Audio'),
          SwitchListTile(
            title: const Text('Sound Effects'),
            subtitle: const Text('Enable UI click and notification sounds'),
            value: _soundEnabled,
            onChanged: (v) async {
              await SoundService.instance.setSoundEnabled(v);
              setState(() => _soundEnabled = v);
            },
          ),
          SwitchListTile(
            title: const Text('Ambient Music'),
            subtitle: const Text('Background music while using the app'),
            value: _ambientEnabled,
            onChanged: _soundEnabled
                ? (v) async {
                    await SoundService.instance.setAmbientEnabled(v);
                    setState(() => _ambientEnabled = v);
                  }
                : null,
          ),
          ListTile(
            title: const Text('Volume'),
            subtitle: Slider(
              value: _volume,
              onChanged: (v) async {
                await SoundService.instance.setVolume(v);
                setState(() => _volume = v);
              },
            ),
          ),
          const Divider(),
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy & Data'),
            subtitle: const Text('Export or delete your data'),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
