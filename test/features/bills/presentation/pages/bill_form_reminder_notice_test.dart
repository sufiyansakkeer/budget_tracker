import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/notifications/notification_permission_notice.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bill_form_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

/// UX-013: a bill's "Remind me" read on while the system blocked Monivo's
/// notifications, so the reminder never arrived.
void main() {
  late BillBloc bloc;

  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: ListBudgetRepository(),
          reconcileTabs: FakeReconcileTabUseCase(),
        ),
      )
      ..registerSingleton<NotificationPermission>(
        NotificationPermission(
          isAllowed: () async => false,
          request: () async => false,
        ),
      );
  });

  tearDown(() async {
    await bloc.close();
    await getIt.reset();
  });

  testWidgets('the blocked notice sits under "Remind me"', (tester) async {
    bloc = buildTestBillBloc(SafeSpendFakeBillRepository());
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider.value(
            value: bloc,
            child: const BillFormScreen(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();

    final more = find.text('More options', skipOffstage: false);
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    const title = 'Notifications are blocked for Monivo';
    expect(find.text(title, skipOffstage: false), findsOneWidget);
    expect(
      tester.getRect(find.text(title, skipOffstage: false)).top,
      greaterThan(
        tester.getRect(find.text('Remind me', skipOffstage: false)).bottom,
      ),
    );
  });
}
