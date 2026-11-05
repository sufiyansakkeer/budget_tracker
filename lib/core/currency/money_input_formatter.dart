import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'money_input.dart';

/// The input formatter of every money field: [MoneyInput.pattern], after
/// reading the separators people type and paste.
///
/// * Spaces are dropped ("1 250").
/// * A mark that appears more than once groups thousands ("1,250,000",
///   "1.250.000"). With both marks, the last one is the decimal point:
///   "1,250.00" and "1.250,00" are both 1250.
/// * A lone comma follows the phone's region. Where numbers use a decimal
///   point (English, India, Oman) it groups thousands, so "1,250" typed key
///   by key is 1250, never 1.25. Where they use a decimal comma it is the
///   point, because that region's decimal pad offers only "," ("27," is
///   "27."), unless the text already had a point (a comma after "27.5"
///   adds nothing).
///
/// Filtering alone kept only the leading match: a pasted "1,250.00" became
/// "1".
class MoneyInputFormatter extends TextInputFormatter {
  /// [decimals] as for [MoneyInput.pattern].
  MoneyInputFormatter(int decimals)
    : _filter = FilteringTextInputFormatter.allow(MoneyInput.pattern(decimals));

  final TextInputFormatter _filter;

  static final RegExp _marks = RegExp(r'[,.\s]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _filter.formatEditUpdate(oldValue, _normalise(oldValue.text, newValue));

  static TextEditingValue _normalise(String before, TextEditingValue value) {
    final text = value.text;
    if (!text.contains(RegExp(r'[,\s]')) && '.'.allMatches(text).length < 2) {
      return value;
    }
    final point = _keptPoint(before, text) ? '.' : _decimalMark(text);
    String clean(String s) =>
        s.replaceAllMapped(_marks, (m) => m[0] == point ? '.' : '');
    int map(int offset) => offset < 0 || offset > text.length
        ? offset
        : clean(text.substring(0, offset)).length;
    return TextEditingValue(
      text: clean(text),
      selection: value.selection.copyWith(
        baseOffset: map(value.selection.baseOffset),
        extentOffset: map(value.selection.extentOffset),
      ),
    );
  }

  /// Whether the part of [after] this edit left alone has a point: a comma
  /// typed or pasted next to it can only be grouping.
  static bool _keptPoint(String before, String after) {
    var start = 0;
    while (start < before.length &&
        start < after.length &&
        before[start] == after[start]) {
      start++;
    }
    var end = 0;
    while (end < before.length - start &&
        end < after.length - start &&
        before[before.length - 1 - end] == after[after.length - 1 - end]) {
      end++;
    }
    return '${after.substring(0, start)}${after.substring(after.length - end)}'
        .contains('.');
  }

  /// The mark [text] uses as its decimal point, or null when every mark in
  /// it groups thousands.
  static String? _decimalMark(String text) {
    final commas = ','.allMatches(text).length;
    final points = '.'.allMatches(text).length;
    if (commas > 0 && points > 0) {
      return text.lastIndexOf(',') > text.lastIndexOf('.') ? ',' : '.';
    }
    if (commas == 1) return _regionUsesDecimalComma() ? ',' : null;
    if (commas > 1 || points > 1) return null;
    return '.';
  }

  /// Whether the phone's region writes decimals with a comma.
  static bool _regionUsesDecimalComma() {
    try {
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      return NumberFormat.decimalPattern(
            locale.toString(),
          ).symbols.DECIMAL_SEP ==
          ',';
    } catch (_) {
      // A region intl doesn't know: the app's own format, a decimal point.
      return false;
    }
  }
}
