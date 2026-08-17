import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/onboarding/domain/entities/budget_entity.dart';
import 'package:monivo/features/onboarding/domain/repository/onboarding_repository.dart';
import 'package:monivo/features/onboarding/domain/usecases/create_budget_usecase.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  bool isFirstLaunch = true;
  BudgetEntity? createdBudget;

  @override
  Future<bool> checkIsFirstLaunch() async {
    return isFirstLaunch;
  }

  @override
  Future<void> setFirstLaunchCompleted() async {
    isFirstLaunch = false;
  }

  @override
  Future<void> createInitialBudget(BudgetEntity budget) async {
    createdBudget = budget;
  }
}

void main() {
  late CreateBudgetUseCase useCase;
  late FakeOnboardingRepository repository;

  setUp(() {
    repository = FakeOnboardingRepository();
    useCase = CreateBudgetUseCase(repository);
  });

  final tBudget = BudgetEntity(
    id: 'test-uuid-123',
    name: 'Personal',
    monthlyAmount: 30000.0,
    remainingAmount: 30000.0,
    currency: 'INR',
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 31),
    createdAt: DateTime(2026, 8, 4),
    updatedAt: DateTime(2026, 8, 4),
  );

  test(
    'should create initial budget and mark first launch completed in repository',
    () async {
      // act
      await useCase(tBudget);

      // assert
      expect(repository.createdBudget, equals(tBudget));
      expect(repository.isFirstLaunch, isFalse);
    },
  );
}
