import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/data/models/budget_model.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/constants/preference_keys.dart';

abstract class OnboardingLocalDataSource {
  bool getIsFirstLaunch();
  Future<void> setIsFirstLaunch(bool isFirstLaunch);
  Future<void> saveBudget(BudgetEntity budget);
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  final SharedPreferences sharedPreferences;
  final AppDatabase database;

  OnboardingLocalDataSourceImpl({
    required this.sharedPreferences,
    required this.database,
  });

  @override
  bool getIsFirstLaunch() {
    return sharedPreferences.getBool(PreferenceKeys.isFirstLaunch) ?? true;
  }

  @override
  Future<void> setIsFirstLaunch(bool isFirstLaunch) async {
    await sharedPreferences.setBool(
      PreferenceKeys.isFirstLaunch,
      isFirstLaunch,
    );
  }

  @override
  Future<void> saveBudget(BudgetEntity budget) async {
    final companion = BudgetModel.toCompanion(budget);
    await database.into(database.budgets).insert(companion);
  }
}
