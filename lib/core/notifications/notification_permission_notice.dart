import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../di/injection.dart';
import '../platform/system_ui_session.dart';
import '../theme/app_tone.dart';
import '../widgets/app_animated_size.dart';
import '../widgets/app_notice.dart';

/// Whether the system lets Monivo post notifications, and the request for
/// it. Registered in DI over the notification service; tests pass their own.
class NotificationPermission {
  /// Reads the permission without asking.
  final Future<bool> Function() isAllowed;

  /// Shows the system prompt when the system still allows one; answers
  /// whether notifications are allowed afterwards.
  final Future<bool> Function() request;

  const NotificationPermission({
    required this.isAllowed,
    required this.request,
  });
}

/// Sits under a reminder switch and says when the system blocks Monivo's
/// notifications, so a switch that reads "on" never hides reminders that
/// will not arrive.
///
/// Asks for permission when [remindersOn] turns on, the moment the user
/// shows they want reminders, never at launch. Checks again when the
/// user comes back to the app, for example from the phone's Settings.
class NotificationPermissionNotice extends StatefulWidget {
  /// Whether the reminders this notice belongs to are on.
  final bool remindersOn;

  /// Defaults to the app's registered [NotificationPermission]; without one
  /// (as in most widget tests) the notice never shows.
  final NotificationPermission? permission;

  const NotificationPermissionNotice({
    super.key,
    required this.remindersOn,
    this.permission,
  });

  @override
  State<NotificationPermissionNotice> createState() =>
      _NotificationPermissionNoticeState();
}

class _NotificationPermissionNoticeState
    extends State<NotificationPermissionNotice> {
  late final AppLifecycleListener _lifecycle;
  bool _blocked = false;

  /// The system answered a request with "no": only the phone's Settings
  /// can allow notifications now, so the notice says where.
  bool _refused = false;

  NotificationPermission? get _permission =>
      widget.permission ??
      (getIt.isRegistered<NotificationPermission>()
          ? getIt<NotificationPermission>()
          : null);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void didUpdateWidget(NotificationPermissionNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remindersOn && !oldWidget.remindersOn) _request();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final permission = _permission;
    if (permission == null || !widget.remindersOn) return;
    try {
      final allowed = await permission.isAllowed();
      if (mounted) setState(() => _blocked = !allowed);
    } catch (e) {
      // Unknown: say nothing rather than warn wrongly.
      debugPrint('[error] Reading the notification permission: $e');
    }
  }

  Future<void> _request() async {
    final permission = _permission;
    if (permission == null) return;
    try {
      // The system prompt takes the foreground; it is not leaving the app.
      final allowed = await SystemUiSession.run(permission.request);
      if (!mounted) return;
      setState(() {
        _blocked = !allowed;
        _refused = !allowed;
      });
    } catch (e) {
      debugPrint('[error] Asking for the notification permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAnimatedSize(
      duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
      alignment: Alignment.topCenter,
      child: widget.remindersOn && _blocked
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.smd),
              child: AppNotice(
                tone: AppTone.caution,
                icon: Icons.notifications_off_outlined,
                title: 'Notifications are blocked for Monivo',
                message: _refused
                    ? "Reminders won't arrive. Open your phone's Settings, "
                          'find Monivo and turn on notifications.'
                    : "Reminders won't arrive until you allow notifications.",
                action: _refused
                    ? null
                    : TextButton(
                        onPressed: _request,
                        child: const Text('Allow notifications'),
                      ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
