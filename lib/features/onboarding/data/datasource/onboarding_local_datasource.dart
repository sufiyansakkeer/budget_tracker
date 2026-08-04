import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../models/budget_model.dart';
import '../../domain/entities/budget_entity.dart';

abstract class OnboardingLocalDataSource {
  bool getIsFirstLaunch();
  Future<void> setIsFirstLaunch(bool isFirstLaunch);
  Future<void> saveBudget(BudgetEntity budget);
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const String _firstLaunchKey = 'isFirstLaunch';
  final SharedPreferences sharedPreferences;
  final AppDatabase database;

  OnboardingLocalDataSourceImpl({
    required this.sharedPreferences,
    required this.database,
  });

  @override
  bool getIsFirstLaunch() {
    return sharedPreferences.getBool(_firstLaunchKey) ?? true;
  }

  @override
  Future<void> setIsFirstLaunch(bool isFirstLaunch) async {
    await sharedPreferences.setBool(_firstLaunchKey, isFirstLaunch);
  }

  @override
  Future<void> saveBudget(BudgetEntity budget) async {
    final companion = BudgetModel.toCompanion(budget);
    await database.into(database.budgets).insert(companion);
  }
}
