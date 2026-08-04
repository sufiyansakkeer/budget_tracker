import '../entities/budget_entity.dart';

abstract class OnboardingRepository {
  Future<bool> checkIsFirstLaunch();
  Future<void> setFirstLaunchCompleted();
  Future<void> createInitialBudget(BudgetEntity budget);
}
