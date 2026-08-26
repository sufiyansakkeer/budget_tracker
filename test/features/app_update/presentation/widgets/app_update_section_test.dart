import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/app_update/domain/entities/app_update_result.dart';
import 'package:monivo/features/app_update/domain/entities/latest_release.dart';
import 'package:monivo/features/app_update/domain/entities/update_status.dart';
import 'package:monivo/features/app_update/domain/repository/app_update_repository.dart';
import 'package:monivo/features/app_update/domain/usecases/check_for_app_update_usecase.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_bloc.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_state.dart';
import 'package:monivo/features/app_update/presentation/widgets/app_update_section.dart';

void main() {
  Widget buildWithBloc(AppUpdateBloc bloc) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<AppUpdateBloc>.value(
          value: bloc,
          child: const SingleChildScrollView(child: AppUpdateSection()),
        ),
      ),
    );
  }

  AppUpdateBloc createBloc({
    AppUpdateState initialState = const AppUpdateInitial(),
  }) {
    return AppUpdateBloc(
      checkForAppUpdateUseCase: _FakeCheckForAppUpdateUseCase(),
    )..emit(initialState);
  }

  testWidgets('shows current version from state', (tester) async {
    final result = const AppUpdateResult(
      status: UpdateStatus.upToDate,
      currentVersion: '1.1.0',
      latestVersion: '1.1.0',
    );
    final bloc = createBloc(initialState: AppUpdateUpToDate(result));
    await tester.pumpWidget(buildWithBloc(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Current Version'), findsOneWidget);
    expect(find.text('v1.1.0'), findsAtLeastNWidgets(1));
    bloc.close();
  });

  testWidgets('shows check button in initial state', (tester) async {
    final bloc = createBloc();
    await tester.pumpWidget(buildWithBloc(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Check for Updates'), findsOneWidget);
    bloc.close();
  });

  testWidgets('shows loading state', (tester) async {
    final bloc = createBloc(initialState: const AppUpdateChecking());
    await tester.pumpWidget(buildWithBloc(bloc));
    await tester.pump();

    expect(find.text('Checking for updates…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    bloc.close();
  });

  testWidgets('shows update available state', (tester) async {
    final result = const AppUpdateResult(
      status: UpdateStatus.updateAvailable,
      currentVersion: '1.0.0',
      latestVersion: '1.1.0',
      releaseUrl: 'https://example.com',
    );
    final bloc = createBloc(initialState: AppUpdateAvailable(result));
    await tester.pumpWidget(buildWithBloc(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('Latest version: v1.1.0'), findsOneWidget);
    expect(find.text('View Update'), findsOneWidget);
    bloc.close();
  });

  testWidgets('shows up-to-date state', (tester) async {
    final result = const AppUpdateResult(
      status: UpdateStatus.upToDate,
      currentVersion: '1.1.0',
      latestVersion: '1.1.0',
    );
    final bloc = createBloc(initialState: AppUpdateUpToDate(result));
    await tester.pumpWidget(buildWithBloc(bloc));
    await tester.pumpAndSettle();

    expect(find.text("You're up to date"), findsOneWidget);
    expect(find.textContaining('latest version'), findsOneWidget);
    bloc.close();
  });

  testWidgets('shows error state', (tester) async {
    final bloc = createBloc(
      initialState: const AppUpdateCheckFailed("Couldn't check for updates."),
    );
    await tester.pumpWidget(buildWithBloc(bloc));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't check for updates."), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    bloc.close();
  });
}

class _FakeCheckForAppUpdateUseCase extends CheckForAppUpdateUseCase {
  _FakeCheckForAppUpdateUseCase()
    : super(repository: _FakeAppUpdateRepository());

  @override
  Future<AppUpdateResult> call() async {
    return const AppUpdateResult(
      status: UpdateStatus.upToDate,
      currentVersion: '1.1.0',
      latestVersion: '1.1.0',
    );
  }
}

class _FakeAppUpdateRepository implements AppUpdateRepository {
  @override
  Future<LatestRelease> getLatestRelease() async {
    return LatestRelease(
      version: '1.1.0',
      title: 'Release 1.1.0',
      releaseUrl: 'https://example.com',
      releaseNotes: '',
      publishedAt: DateTime(2025),
    );
  }
}
