import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/app_update/domain/entities/latest_release.dart';
import 'package:monivo/features/app_update/domain/repository/app_update_repository.dart';
import 'package:monivo/features/app_update/domain/usecases/check_for_app_update_usecase.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_bloc.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_event.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_state.dart';

class _ReleaseRepository implements AppUpdateRepository {
  @override
  Future<LatestRelease> getLatestRelease() async => LatestRelease(
    version: '1.1.0',
    title: 'Release 1.1.0',
    releaseUrl: 'https://example.com',
    releaseNotes: '',
    publishedAt: DateTime(2026, 10, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // package_info has no handler here, so reading the installed version
  // throws, as when the platform call fails on a device.
  test(
    'an installed version that cannot be read ends the check as failed',
    () async {
      final bloc = AppUpdateBloc(
        checkForAppUpdateUseCase: CheckForAppUpdateUseCase(
          repository: _ReleaseRepository(),
        ),
      );
      addTearDown(bloc.close);

      final states = expectLater(
        bloc.stream,
        emitsInOrder([
          const AppUpdateChecking(),
          const AppUpdateCheckFailed('Unable to check for updates.'),
        ]),
      );
      bloc.add(const AppUpdateManualCheck());

      await states;
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
