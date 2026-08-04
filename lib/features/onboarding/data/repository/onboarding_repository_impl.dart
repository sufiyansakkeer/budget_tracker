import '../../domain/entities/budget_entity.dart';
import '../../domain/repository/onboarding_repository.dart';
import '../datasource/onboarding_local_datasource.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource localDataSource;

  OnboardingRepositoryImpl({required this.localDataSource});

  @override
  Future<bool> checkIsFirstLaunch() async {
    return localDataSource.getIsFirstLaunch();
  }

  @override
  Future<void> setFirstLaunchCompleted() async {
    await localDataSource.setIsFirstLaunch(false);
  }

  @override
  Future<void> createInitialBudget(BudgetEntity budget) async {
    await localDataSource.saveBudget(budget);
  }
}
