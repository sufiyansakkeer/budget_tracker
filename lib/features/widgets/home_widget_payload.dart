import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/currency/currency_formatter.dart';
import '../../core/theme/app_colors_extension.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tone.dart';
import '../../core/widgets/app_money.dart';
import '../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../dashboard/presentation/widgets/safe_to_spend_copy.dart';
import '../dashboard/presentation/widgets/spending_status.dart';
import '../settings/domain/entities/color_palette_entity.dart';

/// What the home-screen widget shows, worded and formatted by the app.
///
/// The native widgets (Android RemoteViews, iOS WidgetKit) only typeset
/// this. Every figure comes from the safe-to-spend engine and is formatted by
/// [AppMoney] and [SafeToSpendCopy] exactly as Home shows it, so the widget
/// never re-implements money rules (symbols, minor units, flooring of safe
/// amounts, right-to-left marks) and can never disagree with the app.
///
/// It is stored as one JSON string, so a widget redraw never reads half of
/// an update.
///
/// Shape (version 2):
/// ```
/// v, state ("ready" | "noBudget" | "error"), asOf (yyyy-MM-dd), updatedAt,
/// colors {light, dark}: surface, ink, muted, track, accent, onAccent,
///   divider, positive, caution, critical, neutral (#AARRGGBB),
/// stale {title, body, short}: shown once the day has turned since [asOf],
/// ready only:
///   label, shortLabel, safe {text, spoken, sign, prefix, whole, fraction,
///   suffix}, status {label, tone}, today {progress, spentLabel, spent,
///   restLabel, rest, restTone?}, budget {name, daysLeft, left, progress,
///   tone}, summary
/// noBudget / error only: message {title, body, short}
/// (`short` is the title for the smallest widget sizes)
/// ```
abstract final class HomeWidgetPayload {
  /// Bumped when the shape changes incompatibly; the native widgets show
  /// their "open the app" state for a version they don't know.
  static const int version = 2;

  static final DateFormat _day = DateFormat('yyyy-MM-dd');

  static String encode(Map<String, Object?> payload) => jsonEncode(payload);

  /// The active budget's figures for [now]'s day.
  ///
  /// [budgetUtilization] is the domain's spent ÷ amount ratio, the same value
  /// Home's budget track draws.
  static Map<String, Object?> ready(
    SafeToSpendEntity e, {
    required double budgetUtilization,
    required DateTime now,
    required ColorPalette palette,
  }) {
    final tone = SafeToSpendStatusVisuals.toneOf(e.status);
    final over = e.overToday > 0;
    // Same drawing geometry as the hero's "today" track.
    final todayUsed = e.dailySafeToSpend > 0
        ? e.todayDiscretionary / e.dailySafeToSpend
        : (e.todayDiscretionary > 0 ? 1.0 : 0.0);
    final summary = StringBuffer(SafeToSpendCopy.heroSemantics(e))
      ..write(' ${SafeToSpendCopy.budgetLeftLine(e)}, ')
      ..write('${SafeToSpendCopy.daysLeft(e).toLowerCase()}.');

    return {
      ..._common('ready', now, palette),
      'label': "Today's Safe Spending",
      'shortLabel': 'Safe today',
      'safe': _money(e.dailySafeToSpend, e.currency, floored: true),
      'status': {
        'label': SafeToSpendCopy.statusLabel(e.status),
        'tone': tone.name,
      },
      'today': {
        'progress': _fraction(todayUsed),
        'spentLabel': 'Spent today',
        'spent': SafeToSpendCopy.amount(e.todayDiscretionary, e.currency),
        'restLabel': over ? 'Over by' : 'Left today',
        'rest': over
            ? SafeToSpendCopy.amount(e.overToday, e.currency)
            : SafeToSpendCopy.safeAmount(e.remainingToday, e.currency),
        // Over today's amount is recoverable, so caution, never critical.
        if (over) 'restTone': AppTone.caution.name,
      },
      'budget': {
        'name': e.budgetName,
        'daysLeft': SafeToSpendCopy.daysLeft(e),
        'left': SafeToSpendCopy.budgetLeftLine(e),
        'progress': _fraction(budgetUtilization),
        'tone': e.availableBalance < 0
            ? AppTone.critical.name
            : AppTone.neutral.name,
      },
      'summary': CurrencyFormatter.forSpeech(summary.toString()),
    };
  }

  /// No budget is running today (none is active, or the active one has not
  /// started or has ended).
  static Map<String, Object?> noBudget({
    required DateTime now,
    required ColorPalette palette,
  }) => {
    ..._common('noBudget', now, palette),
    'message': {
      'title': 'No budget running',
      'body': 'Open Monivo to start or choose a budget.',
      'short': 'No budget',
    },
  };

  /// Today's figures could not be worked out.
  static Map<String, Object?> error({
    required DateTime now,
    required ColorPalette palette,
  }) => {
    ..._common('error', now, palette),
    'message': {
      'title': "Couldn't load your budget",
      'body': 'Open Monivo and try again.',
      'short': "Couldn't load",
    },
  };

  static Map<String, Object?> _common(
    String state,
    DateTime now,
    ColorPalette palette,
  ) => {
    'v': version,
    'state': state,
    'asOf': _day.format(now),
    'updatedAt': now.toIso8601String(),
    'stale': {
      'title': 'Tap to update',
      'body': "Open Monivo to see today's safe spending.",
      'short': 'Tap to update',
    },
    'colors': {
      'light': _colors(AppTheme.buildLightTheme(palette)),
      'dark': _colors(AppTheme.buildDarkTheme(palette)),
    },
  };

  static Map<String, Object?> _money(
    double amount,
    String currency, {
    bool floored = false,
  }) {
    final m = AppMoney.describe(amount, currency: currency, floored: floored);
    return {
      'text': m.parts.join(),
      'spoken': m.spoken,
      'sign': m.parts.sign,
      'prefix': m.parts.prefix,
      'whole': m.parts.whole,
      'fraction': m.parts.fraction,
      'suffix': m.parts.suffix,
    };
  }

  /// The palette's colours as the app ships them for one brightness: the
  /// raised card the hero sits on, its text, the track and the status tones.
  static Map<String, String> _colors(ThemeData theme) {
    final scheme = theme.colorScheme;
    final tokens = theme.extension<AppColorTokens>()!;
    return {
      'surface': _hex(tokens.card),
      'ink': _hex(scheme.onSurface),
      'muted': _hex(tokens.textSecondary),
      'track': _hex(scheme.surfaceContainerHighest),
      'accent': _hex(scheme.primary),
      'onAccent': _hex(scheme.onPrimary),
      'divider': _hex(tokens.divider),
      for (final tone in const [
        AppTone.positive,
        AppTone.caution,
        AppTone.critical,
        AppTone.neutral,
      ])
        tone.name: _hex(tokens.tone(tone).accent),
    };
  }

  static double _fraction(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
