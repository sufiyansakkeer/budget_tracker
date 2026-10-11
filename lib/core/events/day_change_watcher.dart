import 'dart:async';

import 'package:flutter/widgets.dart';

import 'refresh_bus.dart';

/// Notices when the calendar day changes while the app stays alive and
/// notifies [RefreshBuses.day], so "today" figures are worked out again.
///
/// An app left in memory overnight used to resume with yesterday's Today's
/// Safe Spending and "Spent today" on screen: the dashboard only reloaded
/// when data changed. The day is checked whenever the app resumes and, while
/// it is in the foreground, just after local midnight.
class DayChangeWatcher {
  DayChangeWatcher({DateTime Function()? clock, RefreshBus? bus})
    : _clock = clock ?? DateTime.now,
      _bus = bus ?? RefreshBuses.day {
    _lastDay = _today();
  }

  final DateTime Function() _clock;
  final RefreshBus _bus;
  late DateTime _lastDay;
  AppLifecycleListener? _lifecycle;
  Timer? _midnight;

  DateTime _today() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Starts checking on every resume and at the next midnight.
  void start() {
    _lifecycle ??= AppLifecycleListener(onResume: check);
    _scheduleMidnight();
  }

  /// Notifies the bus when the calendar day differs from the last one seen.
  /// Returns whether it did.
  bool check() {
    _scheduleMidnight();
    final today = _today();
    if (today == _lastDay) return false;
    _lastDay = today;
    _bus.notifyChanged();
    return true;
  }

  /// Arms a timer for just after the next local midnight. Only while
  /// started, so a watcher used directly (tests) never leaves a timer.
  void _scheduleMidnight() {
    if (_lifecycle == null) return;
    _midnight?.cancel();
    final now = _clock();
    // Calendar arithmetic: a daylight-saving day still ends at midnight.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      check,
    );
  }

  /// Stops watching and cancels the midnight timer.
  void dispose() {
    _lifecycle?.dispose();
    _lifecycle = null;
    _midnight?.cancel();
    _midnight = null;
  }
}
