import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../../features/onboarding/data/datasource/onboarding_local_datasource.dart';
import '../../features/onboarding/data/repository/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/repository/onboarding_repository.dart';
import '../../features/onboarding/domain/usecases/check_first_launch_usecase.dart';
import '../../features/onboarding/domain/usecases/create_budget_usecase.dart';
import '../../features/onboarding/presentation/bloc/onboarding_bloc.dart';

final GetIt getIt = GetIt.instance;

Future<void> initDependencyInjection() async {
  // 1. SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // 2. Local Database
  final database = AppDatabase();
  getIt.registerSingleton<AppDatabase>(database);

  // 3. Onboarding Feature - Datasources
  getIt.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(
      sharedPreferences: getIt<SharedPreferences>(),
      database: getIt<AppDatabase>(),
    ),
  );

  // 4. Onboarding Feature - Repositories
  getIt.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(
      localDataSource: getIt<OnboardingLocalDataSource>(),
    ),
  );

  // 5. Onboarding Feature - Use Cases
  getIt.registerLazySingleton<CheckFirstLaunchUseCase>(
    () => CheckFirstLaunchUseCase(getIt<OnboardingRepository>()),
  );

  getIt.registerLazySingleton<CreateBudgetUseCase>(
    () => CreateBudgetUseCase(getIt<OnboardingRepository>()),
  );

  // 6. Onboarding Feature - BLoC
  getIt.registerFactory<OnboardingBloc>(
    () => OnboardingBloc(
      createBudgetUseCase: getIt<CreateBudgetUseCase>(),
    ),
  );
}
