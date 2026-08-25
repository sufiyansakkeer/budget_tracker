import 'package:flutter/material.dart';
import '../di/injection.dart' as di;
import '../../features/settings/domain/entities/settings_failure.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';

/// Provider that manages currency settings based on user preferences.
class CurrencyProvider extends ChangeNotifier {
  final LoadSettingsUseCase _loadSettingsUseCase;
  String _currencyCode = 'INR';
  String _currencySymbol = '₹';

  CurrencyProvider({LoadSettingsUseCase? loadSettingsUseCase})
    : _loadSettingsUseCase =
          loadSettingsUseCase ?? di.getIt<LoadSettingsUseCase>() {
    _loadCurrencySettings();
  }

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;

  Future<void> _loadCurrencySettings() async {
    try {
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        final settings = data;
        _currencyCode = settings.currencyCode;
        _currencySymbol = settings.currencySymbol;
        notifyListeners();
      }
    } catch (e) {
      // Keep default currency on error
    }
  }

  void updateCurrency(String code, String symbol) {
    _currencyCode = code;
    _currencySymbol = symbol;
    notifyListeners();
  }

  /// Format amount with current currency symbol
  String formatAmount(double amount) {
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }
}
