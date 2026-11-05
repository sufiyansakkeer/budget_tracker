import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/notifications/notification_permission_notice.dart';
import '../../../../core/platform/system_ui_session.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/domain/entities/notification_settings.dart';
import '../../../settings/domain/entities/settings_failure.dart';
import '../../../settings/domain/usecases/load_settings_usecase.dart';

/// Home's one-time offer to allow notifications.
///
/// The app never asks at launch (the prompt used to land over onboarding),
/// so without this a fresh install would keep reminders "on" that the
/// system blocks. Shown while reminders are on and notifications are not
/// allowed, until the user answers it once either way.
class NotificationPrimingCard extends StatefulWidget {
  /// Set once the offer has been answered; it never shows again.
  static const String answeredKey = 'notification_priming_answered';

  /// Defaults to the app's registered [NotificationPermission]; without one
  /// (as in most widget tests) the card never shows.
  final NotificationPermission? permission;

  /// The saved reminder settings; defaults to [LoadSettingsUseCase].
  final Future<NotificationSettings?> Function()? loadSettings;

  const NotificationPrimingCard({
    super.key,
    this.permission,
    this.loadSettings,
  });

  @override
  State<NotificationPrimingCard> createState() =>
      _NotificationPrimingCardState();
}

class _NotificationPrimingCardState extends State<NotificationPrimingCard> {
  NotificationSettings? _offering;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  NotificationPermission? get _permission =>
      widget.permission ??
      (getIt.isRegistered<NotificationPermission>()
          ? getIt<NotificationPermission>()
          : null);

  Future<NotificationSettings?> _settings() async {
    if (widget.loadSettings case final load?) return load();
    final result = await getIt<LoadSettingsUseCase>()();
    return result is SettingsSuccess<AppSettings>
        ? result.data.notifications
        : null;
  }

  Future<void> _decide() async {
    final permission = _permission;
    if (permission == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(NotificationPrimingCard.answeredKey) ?? false) return;
      final settings = await _settings();
      if (settings == null || !settings.notificationsEnabled) return;
      if (await permission.isAllowed()) return;
      if (mounted) setState(() => _offering = settings);
    } catch (e) {
      // Unknown: offer nothing rather than nag.
      debugPrint('[error] Deciding the notification offer: $e');
    }
  }

  Future<void> _answer({required bool allow}) async {
    setState(() => _offering = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(NotificationPrimingCard.answeredKey, true);
    } catch (e) {
      debugPrint('[error] Saving the notification offer answer: $e');
    }
    final permission = _permission;
    if (!allow || permission == null) return;
    try {
      // The system prompt takes the foreground; it is not leaving the app.
      await SystemUiSession.run(permission.request);
    } catch (e) {
      debugPrint('[error] Asking for the notification permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _offering;
    if (settings == null) return const SizedBox.shrink();
    final morning = settings.morningReminderEnabled
        ? TimeOfDay(
            hour: settings.morningReminderTime.hour,
            minute: settings.morningReminderTime.minute,
          ).format(context)
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppNotice(
        tone: AppTone.info,
        icon: Icons.notifications_outlined,
        title: morning != null
            ? "Get Today's Safe Spending each morning"
            : 'Get reminders from Monivo',
        message: morning != null
            ? 'Monivo sends it at $morning and reminds you before bills are '
                  'due. Allow notifications to get them.'
            : 'Monivo reminds you before bills are due. Allow notifications '
                  'to get them.',
        action: Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => _answer(allow: true),
              child: const Text('Allow notifications'),
            ),
            TextButton(
              onPressed: () => _answer(allow: false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
