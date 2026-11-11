import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../app/services.dart';
import 'home_screen.dart';
import 'tutorial_screen.dart';

/// Sound, vibration, colour-blind patterns, privacy options (only
/// when consent requires them), privacy policy, tutorial, credits and
/// licences, version.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final st = s.settings;
    final policy = Uri.tryParse(s.privacyPolicyUrl);
    final hasPolicy =
        s.privacyPolicyUrl.isNotEmpty && policy != null && policy.hasScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: GameColors.background,
        foregroundColor: GameColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: GameSpacing.sm),
        children: [
          _Toggle('Sound effects', Icons.volume_up_rounded, st.sound),
          _Toggle('Vibration', Icons.vibration_rounded, st.haptics),
          _Toggle(
            'Colour-blind patterns',
            Icons.texture_rounded,
            st.colourBlindPatterns,
            subtitle: 'Adds a pattern to each block colour',
          ),
          const Divider(color: GameColors.gridLine),
          if (s.consent.privacyOptionsRequired)
            ListTile(
              key: const Key('privacyOptions'),
              leading: const Icon(Icons.privacy_tip_rounded),
              title: const Text('Privacy options'),
              subtitle: const Text('Change your ad consent choices'),
              onTap: () async {
                await s.consent.showPrivacyOptionsForm();
                if (mounted) setState(() {});
              },
            ),
          if (hasPolicy)
            ListTile(
              key: const Key('privacyPolicy'),
              leading: const Icon(Icons.description_rounded),
              title: const Text('Privacy policy'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => s.openUrl?.call(policy),
            ),
          ListTile(
            key: const Key('tutorial'),
            leading: const Icon(Icons.school_rounded),
            title: const Text('How to play'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    TutorialScreen(onDone: Navigator.of(context).pop),
              ),
            ),
          ),
          ListTile(
            key: const Key('credits'),
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Credits and licences'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: kAppTitle,
              applicationVersion: s.version,
              applicationLegalese:
                  'Game design, graphics and sound effects are original and '
                  'made in code for this game. Font: Nunito (SIL Open Font '
                  'Licence). Open-source licences are listed below.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tag_rounded),
            title: const Text('Version'),
            trailing: Text(
              s.version,
              style: const TextStyle(color: GameColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.icon, this.value, {this.subtitle});

  final String label;
  final IconData icon;
  final ValueNotifier<bool> value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: value,
    builder: (_, on, _) => SwitchListTile(
      key: Key('toggle:$label'),
      secondary: Icon(icon),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: on,
      onChanged: (v) => value.value = v,
    ),
  );
}
