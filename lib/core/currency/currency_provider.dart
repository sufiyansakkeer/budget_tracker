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
    reload();
  }

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;

  /// Re-reads the currency setting (after a restore replaced it).
  Future<void> reload() async {
    try {
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        final settings = data;
        _currencyCode = settings.currencyCode;
        _currencySymbol = settings.currencySymbol;
        notifyListeners();
      }
    } catch (e) {
      // Keep the default currency.
      debugPrint('[error] Loading the currency setting: $e');
    }
  }

  void updateCurrency(String code, String symbol) {
    _currencyCode = code;
    _currencySymbol = symbol;
    notifyListeners();
  }
}
