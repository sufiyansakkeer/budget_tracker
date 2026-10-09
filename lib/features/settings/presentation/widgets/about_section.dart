import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import 'settings_section.dart';
import 'settings_tile.dart';

/// The app's version, what happens to your data, and the licence page.
class AboutSection extends StatefulWidget {
  const AboutSection({super.key});

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  static const _privacy = InfoContent(
    title: 'Privacy',
    whatIsThis:
        'Your budgets, expenses, bills and settings are stored only on this '
        'device, and everything works without an internet connection.',
    additionalNotes:
        '• No account is needed\n'
        '• No personal or financial data is collected or sent anywhere\n'
        '• The only network requests are the optional "Check for updates", '
        'which asks GitHub for the latest release version, and the currency '
        'converter, which fetches exchange rates from Frankfurter',
  );

  /// Kept once read, so a rebuild (theme change, settings reload) or a
  /// return to Settings never blanks the version to "…" and fills it in
  /// again. The value is cached rather than the future: a future completes
  /// in the zone that created it, which a later test's zone never drains.
  static PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    if (_info == null) {
      PackageInfo.fromPlatform().then((info) {
        _info = info;
        if (mounted) setState(() {});
      }, onError: (Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final appName = info?.appName ?? 'Monivo';
    final version = info == null
        ? '…'
        : 'v${info.version}'
              '${info.buildNumber.isNotEmpty ? ' (${info.buildNumber})' : ''}';
    return SettingsSection(
      title: 'About',
      children: [
        SettingsTile(
          icon: Icons.info_outline_rounded,
          title: appName,
          value: version,
        ),
        SettingsTile(
          icon: Icons.lock_outline_rounded,
          title: 'Privacy',
          subtitle: 'All data stays on this device',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => InfoIcon.showSheet(context, _privacy),
        ),
        SettingsTile(
          icon: Icons.description_outlined,
          title: 'Open source licenses',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: appName,
            applicationVersion: info?.version,
          ),
        ),
      ],
    );
  }
}
