import '../repository/onboarding_repository.dart';

class CheckFirstLaunchUseCase {
  final OnboardingRepository repository;

  CheckFirstLaunchUseCase(this.repository);

  Future<bool> call() async {
    return await repository.checkIsFirstLaunch();
  }
}
