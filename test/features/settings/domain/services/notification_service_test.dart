import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/usecases/schedule_bill_reminder_usecase.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';

import 'package:monivo/features/settings/domain/services/notification_service.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin, BudgetRepository])
import '../../../../helpers/safe_to_spend_fakes.dart';
import '../../../../integration/app_harness.dart';
import 'notification_service_test.mocks.dart';

class FakeGetSpendingTargetsUseCase implements GetSpendingTargetsUseCase {
  PerBudgetSpendingTargetResult? perBudgetResultToReturn;

  /// When set, answers [callPerBudget] per reference date.
  PerBudgetSpendingTargetResult Function(DateTime? referenceDate)?
  perBudgetResultFor;

  /// Every reference date [callPerBudget] was asked for, in order.
  final List<DateTime?> perBudgetReferenceDates = [];

  FakeGetSpendingTargetsUseCase({this.perBudgetResultToReturn});

  @override
  final BudgetRepository repository = MockBudgetRepository();
  @override
  final BudgetCalculationService calculationService =
      BudgetCalculationService();

  @override
  Future<PerBudgetSpendingTargetResult> callPerBudget({
    DateTime? referenceDate,
  }) async {
    perBudgetReferenceDates.add(referenceDate);
    final resultFor = perBudgetResultFor;
    if (resultFor != null) return resultFor(referenceDate);
    if (perBudgetResultToReturn != null) {
      return perBudgetResultToReturn!;
    }
    return const PerBudgetSpendingTargetNoBudget();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mockito needs a dummy value for BudgetResult<BudgetCalculationContext>
  // because it's a sealed class and Mockito can't auto-generate one.
  provideDummy<BudgetResult<BudgetCalculationContext>>(
    const BudgetError(
      BudgetFailure(type: BudgetErrorType.notFound, message: 'dummy'),
    ),
  );

  late NotificationService notificationService;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockBudgetRepository mockBudgetRepository;
  late FakeGetSpendingTargetsUseCase fakeSpendingTargetsUseCase;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockBudgetRepository = MockBudgetRepository();
    fakeSpendingTargetsUseCase = FakeGetSpendingTargetsUseCase(
      perBudgetResultToReturn: PerBudgetSpendingTargetSuccess(
        budgetLimits: [
          BudgetDailyLimitEntity(
            budgetId: 'b1',
            budgetName: 'Food',
            dailyLimit: 1500,
            spentToday: 500,
            remainingToday: 1000,
            exceededToday: 0,
            progress: 0.33,
            isOverLimit: false,
            status: SpendingTargetStatus.onTrack,
            budgetStatus: BudgetStatus.underBudget,
            budgetUtilization: 0.38,
            monthlyAmount: 30000,
            totalSpent: 11500,
            remainingBudget: 18500,
            remainingDays: 22,
            weeklyTarget: 10500,
            weeklySpent: 3500,
            weeklyRemaining: 7000,
            weeklyExceeded: 0,
            weeklyProgress: 0.33,
            weeklyStatus: SpendingTargetStatus.onTrack,
            currency: 'INR',
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 31),
          ),
        ],
      ),
    );
    notificationService = NotificationService(
      plugin: mockPlugin,
      spendingTargetsUseCase: fakeSpendingTargetsUseCase,
      rescheduleTabReminders: () async {},
      onPayLaterTap: (_) {},
    );
    when(
      mockPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
    when(
      mockPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
  });

  /// Helper: stub the plugin's initialize and zonedSchedule methods
  /// so that scheduleAll / scheduleTestNotification can proceed.
  void stubPluginInitialization() {
    when(
      mockPlugin.initialize(
        any,
        onDidReceiveNotificationResponse: anyNamed(
          'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(
      mockPlugin.zonedSchedule(
        any,
        any,
        any,
        any,
        any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
      ),
    ).thenAnswer((_) async {});
  }

  group('NotificationService', () {
    group('initialize', () {
      test('should initialize successfully', () async {
        when(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => true);

        final result = await notificationService.initialize();

        expect(result, true);
        expect(notificationService.isInitialized, true);
        verify(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
          ),
        ).called(1);
      });

      test('should handle initialization failure', () async {
        when(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => false);

        final result = await notificationService.initialize();

        expect(result, false);
        expect(notificationService.isInitialized, false);
      });
    });

    group('requestPermission', () {
      test('should request permission on Android', () async {
        final mockAndroid = FakeAndroidFlutterLocalNotificationsPlugin();
        when(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => true);
        when(
          mockPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(mockAndroid);

        final result = await notificationService.requestPermission();

        expect(result, true);
        expect(mockAndroid.requestNotificationsPermissionCallCount, 1);
      });

      test('should request permission on iOS', () async {
        when(
          mockPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(null);
        when(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => true);

        final result = await notificationService.requestPermission();

        expect(result, true);
      });
    });

    test('UX-013: reads whether Android blocks notifications, without '
        'asking', () async {
      final android = FakeAndroidFlutterLocalNotificationsPlugin()
        ..enabled = false;
      when(
        mockPlugin.initialize(
          any,
          onDidReceiveNotificationResponse: anyNamed(
            'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((_) async => true);
      when(
        mockPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);

      expect(await notificationService.areNotificationsEnabled(), isFalse);
      android.enabled = true;
      expect(await notificationService.areNotificationsEnabled(), isTrue);
      expect(android.requestNotificationsPermissionCallCount, 0);
    });

    group('scheduleAll', () {
      setUp(() {
        stubPluginInitialization();
      });

      test(
        'should schedule morning notification with dynamic safe spending',
        () async {
          when(
            mockBudgetRepository.getActiveBudgetId(),
          ).thenAnswer((_) async => 'budget-1');

          final now = DateTime.now();
          when(
            mockBudgetRepository.getCalculationContext(
              'budget-1',
              referenceDate: anyNamed('referenceDate'),
            ),
          ).thenAnswer(
            (_) async => BudgetSuccess(
              BudgetCalculationContext(
                budget: BudgetEntity(
                  id: 'budget-1',
                  name: 'Test Budget',
                  monthlyAmount: 30000,
                  remainingAmount: 18500,
                  currency: 'INR',
                  startDate: DateTime(now.year, now.month, 1),
                  endDate: DateTime(now.year, now.month + 1, 0),
                  createdAt: now,
                  updatedAt: now,
                ),
                statistics: const MonthlyStatisticsEntity(
                  totalSpent: 11500,
                  expenseCount: 10,
                  todaySpending: 500,
                ),
                referenceDate: now,
              ),
            ),
          );

          final settings = AppSettings(
            notifications: const NotificationSettings(
              notificationsEnabled: true,
              morningReminderEnabled: true,
              eveningSummaryEnabled: true,
              overspendingAlertsEnabled: true,
              dailyRemindersEnabled: true,
              noExpenseReminderEnabled: true,
            ),
          );

          await notificationService.scheduleAll(settings);

          verify(mockPlugin.cancelAllPendingNotifications()).called(1);
          // Verify the morning notification has a per-budget body
          verify(
            mockPlugin.zonedSchedule(
              NotificationService.morningReminderId,
              "Today's Safe Spending",
              argThat(contains('Food')),
              any,
              any,
              androidScheduleMode: anyNamed('androidScheduleMode'),
              matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
            ),
          ).called(1);
        },
      );

      test('should use fallback text when no active budget exists', () async {
        // When no spending target is available, use fallback text
        fakeSpendingTargetsUseCase.perBudgetResultToReturn = null;

        final settings = AppSettings(
          notifications: const NotificationSettings(
            notificationsEnabled: true,
            morningReminderEnabled: true,
            eveningSummaryEnabled: false,
          ),
        );

        await notificationService.scheduleAll(settings);

        // Should use the fallback text when no budget exists
        verify(
          mockPlugin.zonedSchedule(
            NotificationService.morningReminderId,
            "Today's Safe Spending",
            'No budget is running today. Open the app to check your budgets.',
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).called(1);
      });

      test('a figure that could not be worked out is not reported as no '
          'budget', () async {
        fakeSpendingTargetsUseCase.perBudgetResultToReturn =
            const PerBudgetSpendingTargetError(
              BudgetFailure(
                type: BudgetErrorType.invalidDate,
                message: 'database is locked',
              ),
            );
        final settings = AppSettings(
          notifications: const NotificationSettings(
            notificationsEnabled: true,
            morningReminderEnabled: true,
            eveningSummaryEnabled: false,
          ),
        );

        await notificationService.scheduleAll(settings);

        verify(
          mockPlugin.zonedSchedule(
            NotificationService.morningReminderId,
            "Today's Safe Spending",
            "Open Monivo to see today's safe spending.",
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).called(1);
      });

      test('a calculation that throws gets the same neutral text', () async {
        fakeSpendingTargetsUseCase.perBudgetResultFor = (_) =>
            throw Exception('database is locked');
        final settings = AppSettings(
          notifications: const NotificationSettings(
            notificationsEnabled: true,
            morningReminderEnabled: true,
            eveningSummaryEnabled: false,
          ),
        );

        await notificationService.scheduleAll(settings);

        verify(
          mockPlugin.zonedSchedule(
            NotificationService.morningReminderId,
            "Today's Safe Spending",
            "Open Monivo to see today's safe spending.",
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).called(1);
      });

      test('should not schedule when notifications disabled', () async {
        final settings = AppSettings(
          notifications: const NotificationSettings(
            notificationsEnabled: false,
          ),
        );

        await notificationService.scheduleAll(settings);

        verify(mockPlugin.cancelAllPendingNotifications()).called(1);
        verifyNever(
          mockPlugin.zonedSchedule(
            NotificationService.morningReminderId,
            any,
            any,
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        );
      });

      test('should schedule the configured reminder time', () async {
        when(
          mockBudgetRepository.getActiveBudgetId(),
        ).thenAnswer((_) async => 'budget-1');

        final now = DateTime.now();
        when(
          mockBudgetRepository.getCalculationContext(
            'budget-1',
            referenceDate: anyNamed('referenceDate'),
          ),
        ).thenAnswer(
          (_) async => BudgetSuccess(
            BudgetCalculationContext(
              budget: BudgetEntity(
                id: 'budget-1',
                name: 'Test Budget',
                monthlyAmount: 30000,
                remainingAmount: 18500,
                currency: 'INR',
                startDate: DateTime(now.year, now.month, 1),
                endDate: DateTime(now.year, now.month + 1, 0),
                createdAt: now,
                updatedAt: now,
              ),
              statistics: const MonthlyStatisticsEntity(
                totalSpent: 11500,
                expenseCount: 10,
                todaySpending: 500,
              ),
              referenceDate: now,
            ),
          ),
        );

        final settings = AppSettings(
          notifications: const NotificationSettings(
            notificationsEnabled: true,
            morningReminderEnabled: true,
            eveningSummaryEnabled: false,
            overspendingAlertsEnabled: false,
            noExpenseReminderEnabled: false,
            morningReminderTime: NotificationTime(hour: 23, minute: 0),
            quietHoursEnabled: true,
            quietHoursStart: NotificationTime(hour: 22, minute: 0),
            quietHoursEnd: NotificationTime(hour: 7, minute: 0),
          ),
        );

        await notificationService.scheduleAll(settings);

        verify(mockPlugin.cancelAllPendingNotifications()).called(1);
        verify(
          mockPlugin.zonedSchedule(
            NotificationService.morningReminderId,
            "Today's Safe Spending",
            any,
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).called(1);
      });
    });

    group('bill reminders (review: re-scheduling wiped them)', () {
      late Set<int> pending;
      late SafeSpendFakeBillRepository bills;
      late BillReminderService billReminders;

      setUp(() {
        stubPluginInitialization();
        // The plugin as the platform behaves: one pending set shared by
        // every caller, cleared as a whole.
        pending = {};
        when(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
            onDidReceiveBackgroundNotificationResponse: anyNamed(
              'onDidReceiveBackgroundNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => true);
        when(
          mockPlugin.zonedSchedule(
            any,
            any,
            any,
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).thenAnswer((invocation) async {
          pending.add(invocation.positionalArguments.first as int);
        });
        when(
          mockPlugin.cancelAllPendingNotifications(),
        ).thenAnswer((_) async => pending.clear());

        bills = SafeSpendFakeBillRepository();
        bills.store['rent'] = BillEntity(
          id: 'rent',
          title: 'Rent',
          amount: 100,
          currency: 'INR',
          category: BillCategory.rent,
          dueDate: DateTime(2099, 1, 10),
          reminderEnabled: true,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        );
        billReminders = BillReminderService(
          plugin: mockPlugin,
          repository: bills,
          onNotificationResponse: (_) {},
        );
        notificationService = NotificationService(
          plugin: mockPlugin,
          spendingTargetsUseCase: fakeSpendingTargetsUseCase,
          rescheduleBillReminders: billReminders.rescheduleAll,
          rescheduleTabReminders: () async {},
          onPayLaterTap: (_) {},
        );
      });

      test('a re-schedule after a bill change keeps the bill reminder '
          'BillBloc just scheduled', () async {
        final rent = bills.store['rent']!;
        await billReminders.scheduleReminder(rent);
        expect(pending, contains(rent.notificationId));

        await notificationService.scheduleAll(
          const AppSettings(
            notifications: NotificationSettings(
              notificationsEnabled: true,
              morningReminderEnabled: true,
              eveningSummaryEnabled: false,
            ),
          ),
        );

        expect(
          pending,
          containsAll([
            rent.notificationId,
            NotificationService.morningReminderId,
          ]),
        );
      });

      test('bill reminders are opted into per bill, so they survive even '
          'with the daily notifications off', () async {
        final rent = bills.store['rent']!;
        await billReminders.scheduleReminder(rent);

        await notificationService.scheduleAll(
          const AppSettings(
            notifications: NotificationSettings(notificationsEnabled: false),
          ),
        );

        expect(pending, {rent.notificationId});
      });

      test(
        'a paid bill or one without a reminder is not brought back',
        () async {
          bills.store['rent'] = bills.store['rent']!.copyWith(isPaid: true);

          await notificationService.scheduleAll(
            const AppSettings(
              notifications: NotificationSettings(notificationsEnabled: false),
            ),
          );

          expect(pending, isEmpty);
        },
      );
    });

    group(
      "morning reminders carry each day's own figure (review: one "
      'repeating text showed the scheduling day\'s amount every morning)',
      () {
        late List<
          ({
            int id,
            String title,
            String body,
            tz.TZDateTime at,
            Object? repeat,
          })
        >
        scheduled;

        const settings = AppSettings(
          notifications: NotificationSettings(
            notificationsEnabled: true,
            morningReminderEnabled: true,
            eveningSummaryEnabled: true,
            morningReminderTime: NotificationTime(hour: 8, minute: 0),
          ),
        );

        setUp(() {
          stubPluginInitialization();
          scheduled = [];
          when(
            mockPlugin.zonedSchedule(
              any,
              any,
              any,
              any,
              any,
              androidScheduleMode: anyNamed('androidScheduleMode'),
              matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
            ),
          ).thenAnswer((invocation) async {
            final args = invocation.positionalArguments;
            scheduled.add((
              id: args[0] as int,
              title: args[1] as String,
              body: args[2] as String,
              at: args[3] as tz.TZDateTime,
              repeat: invocation.namedArguments[#matchDateTimeComponents],
            ));
          });
        });

        /// The service on a fixed clock. Tests have no platform time zone, so
        /// the service falls back to UTC; the clock is in UTC to match.
        NotificationService serviceAt(
          DateTime clock, {
          GetSpendingTargetsUseCase? targets,
        }) => NotificationService(
          plugin: mockPlugin,
          spendingTargetsUseCase: targets ?? fakeSpendingTargetsUseCase,
          clock: () => clock,
          rescheduleTabReminders: () async {},
          onPayLaterTap: (_) {},
        );

        List<
          ({
            int id,
            String title,
            String body,
            tz.TZDateTime at,
            Object? repeat,
          })
        >
        mornings() =>
            scheduled.where((s) => s.title == "Today's Safe Spending").toList();

        /// A running "Food" budget whose amount that day is day-of-month × 100.
        PerBudgetSpendingTargetResult foodOn(DateTime? day) {
          final base =
              (fakeSpendingTargetsUseCase.perBudgetResultToReturn!
                      as PerBudgetSpendingTargetSuccess)
                  .budgetLimits
                  .single;
          final limit = BudgetDailyLimitEntity(
            budgetId: base.budgetId,
            budgetName: base.budgetName,
            dailyLimit: day!.day * 100.0,
            spentToday: 0,
            remainingToday: day.day * 100.0,
            exceededToday: 0,
            progress: 0,
            isOverLimit: false,
            status: base.status,
            budgetStatus: base.budgetStatus,
            budgetUtilization: base.budgetUtilization,
            monthlyAmount: base.monthlyAmount,
            totalSpent: base.totalSpent,
            remainingBudget: base.remainingBudget,
            remainingDays: base.remainingDays,
            weeklyTarget: base.weeklyTarget,
            weeklySpent: base.weeklySpent,
            weeklyRemaining: base.weeklyRemaining,
            weeklyExceeded: base.weeklyExceeded,
            weeklyProgress: base.weeklyProgress,
            weeklyStatus: base.weeklyStatus,
            currency: 'INR',
            startDate: base.startDate,
            endDate: base.endDate,
          );
          return PerBudgetSpendingTargetSuccess(budgetLimits: [limit]);
        }

        test('scheduled in the evening: the first reminder is tomorrow with '
            "tomorrow's figure, then one per morning for a week", () async {
          fakeSpendingTargetsUseCase.perBudgetResultFor = foodOn;

          await serviceAt(DateTime.utc(2026, 8, 10, 21)).scheduleAll(settings);

          const days = NotificationService.morningReminderDays;
          expect(fakeSpendingTargetsUseCase.perBudgetReferenceDates, [
            for (var i = 0; i < days; i++) DateTime(2026, 8, 11 + i),
          ]);
          final reminders = mornings();
          expect(reminders.map((r) => r.id), [
            for (var i = 0; i < days; i++)
              NotificationService.morningReminderIdFor(i),
          ]);
          expect(reminders.map((r) => r.id).toSet(), hasLength(days));
          for (var i = 0; i < days; i++) {
            final day = 11 + i;
            expect(reminders[i].at, tz.TZDateTime(tz.local, 2026, 8, day, 8));
            expect(
              reminders[i].repeat,
              isNull,
              reason: 'one-off, never repeats',
            );
            expect(
              reminders[i].body,
              'Food: you can safely spend '
              '${CurrencyFormatter.formatFloored(day * 100.0, code: 'INR')} '
              'today.',
            );
          }
        });

        test('scheduled before the morning time: the first reminder is today, '
            "with today's figure", () async {
          fakeSpendingTargetsUseCase.perBudgetResultFor = foodOn;

          await serviceAt(DateTime.utc(2026, 8, 10, 7)).scheduleAll(settings);

          expect(
            fakeSpendingTargetsUseCase.perBudgetReferenceDates.first,
            DateTime(2026, 8, 10),
          );
          expect(mornings().first.at, tz.TZDateTime(tz.local, 2026, 8, 10, 8));
          expect(mornings().last.at, tz.TZDateTime(tz.local, 2026, 8, 16, 8));
        });

        test('the reminders cross a month end on calendar dates', () async {
          fakeSpendingTargetsUseCase.perBudgetResultFor = foodOn;

          await serviceAt(DateTime.utc(2026, 8, 29, 21)).scheduleAll(settings);

          expect(fakeSpendingTargetsUseCase.perBudgetReferenceDates, [
            DateTime(2026, 8, 30),
            DateTime(2026, 8, 31),
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 2),
            DateTime(2026, 9, 3),
            DateTime(2026, 9, 4),
            DateTime(2026, 9, 5),
          ]);
        });

        test('a morning after the budget ends says no budget is running, '
            "instead of repeating the last day's amount", () async {
          // The budget's last day is 12 Aug.
          fakeSpendingTargetsUseCase.perBudgetResultFor = (day) =>
              day!.isAfter(DateTime(2026, 8, 12))
              ? const PerBudgetSpendingTargetNoBudget()
              : foodOn(day);

          await serviceAt(DateTime.utc(2026, 8, 10, 21)).scheduleAll(settings);

          final bodies = mornings().map((r) => r.body).toList();
          expect(bodies[0], contains('₹1,100'));
          expect(bodies[1], contains('₹1,200'));
          expect(
            bodies.skip(2),
            everyElement(
              'No budget is running today. Open the app to check your budgets.',
            ),
          );
        });

        test(
          'the evening summary, which has no amount, still repeats daily',
          () async {
            fakeSpendingTargetsUseCase.perBudgetResultFor = foodOn;

            await serviceAt(
              DateTime.utc(2026, 8, 10, 21),
            ).scheduleAll(settings);

            final evening = scheduled.singleWhere(
              (s) => s.id == NotificationService.eveningSummaryId,
            );
            expect(evening.repeat, DateTimeComponents.time);
            expect(mornings().map((r) => r.repeat), everyElement(isNull));
          },
        );

        test('real engine: ₹3,000 over 30 days, ₹500 spent at 9 pm on day 1 → '
            "day 2's reminder says ₹86.20, not day 1's ₹100", () async {
          final app = await AppHarness.create();
          addTearDown(app.dispose);
          await app.addBudget(
            id: 'food',
            name: 'Food',
            amount: 3000,
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 30),
          );
          await app.expenseRepository.createExpense(
            ExpenseEntity(
              id: 'dinner',
              budgetId: 'food',
              amount: 500,
              categoryId: 'food',
              date: DateTime(2026, 8, 1),
              time: DateTime(2026, 8, 1, 21),
              createdAt: DateTime(2026, 8, 1, 21),
              updatedAt: DateTime(2026, 8, 1, 21),
            ),
          );

          await serviceAt(
            DateTime.utc(2026, 8, 1, 21),
            targets: app.getSpendingTargets,
          ).scheduleAll(settings);

          String amount(double value) =>
              CurrencyFormatter.formatFloored(value, code: 'INR');
          final bodies = mornings().map((r) => r.body).toList();
          expect(bodies, hasLength(NotificationService.morningReminderDays));
          // 2 Aug: 2,500 left over 2–30 Aug (29 days).
          expect(amount(2500 / 29), '₹86.20');
          expect(bodies[0], 'Food: you can safely spend ₹86.20 today.');
          expect(bodies[0], isNot(contains(amount(100))));
          // Nothing more recorded: each later morning spreads it over fewer
          // days (3 Aug: 28 days … 8 Aug: 23 days).
          for (var i = 1; i < bodies.length; i++) {
            expect(
              bodies[i],
              'Food: you can safely spend ${amount(2500 / (29 - i))} today.',
            );
          }
        });
      },
    );

    group('pay later reminders: restore and tap routing', () {
      late List<String> opened;
      late List<String> order;
      late NotificationService service;

      /// The tap handler the platform holds: the one the latest
      /// `initialize` call passed (a later call without one clears it).
      DidReceiveNotificationResponseCallback? handler;

      const disabled = AppSettings(
        notifications: NotificationSettings(notificationsEnabled: false),
      );

      NotificationResponse tap(String? payload) => NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      );

      NotificationService build({
        Future<void> Function()? rescheduleTabReminders,
        Future<void> Function()? rescheduleBillReminders,
      }) => NotificationService(
        plugin: mockPlugin,
        spendingTargetsUseCase: fakeSpendingTargetsUseCase,
        rescheduleBillReminders: rescheduleBillReminders,
        rescheduleTabReminders:
            rescheduleTabReminders ?? () async => order.add('tabs'),
        onPayLaterTap: opened.add,
      );

      setUp(() {
        stubPluginInitialization();
        opened = [];
        order = [];
        handler = null;
        when(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((invocation) async {
          handler =
              invocation.namedArguments[#onDidReceiveNotificationResponse]
                  as DidReceiveNotificationResponseCallback?;
          return true;
        });
        when(
          mockPlugin.cancelAllPendingNotifications(),
        ).thenAnswer((_) async => order.add('cancel'));
        when(
          mockPlugin.getNotificationAppLaunchDetails(),
        ).thenAnswer((_) async => null);
        service = build();
      });

      test('tapping a pay later reminder opens its tab', () async {
        await service.initialize();

        handler!(tap('pay_later:tab-1'));

        expect(opened, ['tab-1']);
      });

      test('other payloads open nothing', () async {
        await service.initialize();

        for (final payload in [
          null,
          '',
          'daily_spending_limit',
          'evening_summary',
          'pay_later:',
          'pay_later',
          'bill:rent',
        ]) {
          handler!(tap(payload));
        }

        expect(opened, isEmpty);
      });

      test('the payload parser', () {
        expect(NotificationService.payLaterTabIdFrom('pay_later:t1'), 't1');
        expect(NotificationService.payLaterTabIdFrom('pay_later:'), isNull);
        expect(NotificationService.payLaterTabIdFrom('t1'), isNull);
        expect(NotificationService.payLaterTabIdFrom(null), isNull);
      });

      test('a reminder tap that launched the app opens the tab once', () async {
        when(mockPlugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => NotificationAppLaunchDetails(
            true,
            notificationResponse: tap('pay_later:t9'),
          ),
        );

        await service.initialize();
        await service.initialize();

        expect(opened, ['t9']);
      });

      // iOS answers false to an initialize that requests no permission,
      // which the app's settings never do (review, fix round 1).
      test('a cold-start reminder tap opens the tab once even when the plugin '
          'answers false', () async {
        when(
          mockPlugin.initialize(
            any,
            onDidReceiveNotificationResponse: anyNamed(
              'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((invocation) async {
          handler =
              invocation.namedArguments[#onDidReceiveNotificationResponse]
                  as DidReceiveNotificationResponseCallback?;
          return false;
        });
        when(mockPlugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => NotificationAppLaunchDetails(
            true,
            notificationResponse: tap('pay_later:t9'),
          ),
        );

        expect(await service.initialize(), isFalse);
        expect(await service.initialize(), isFalse);

        expect(opened, ['t9']);
        // A tap while the app runs still reaches the handler it registered.
        handler!(tap('pay_later:t2'));
        expect(opened, ['t9', 't2']);
      });

      test('a launch that was not a notification tap opens nothing', () async {
        when(mockPlugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => NotificationAppLaunchDetails(
            false,
            notificationResponse: tap('pay_later:t9'),
          ),
        );

        await service.initialize();

        expect(opened, isEmpty);
      });

      test('a launch from another notification opens nothing', () async {
        when(mockPlugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => NotificationAppLaunchDetails(
            true,
            notificationResponse: tap('daily_spending_limit'),
          ),
        );

        await service.initialize();

        expect(opened, isEmpty);
      });

      test('launch details that cannot be read do not fail start-up', () async {
        when(
          mockPlugin.getNotificationAppLaunchDetails(),
        ).thenThrow(Exception('channel'));

        expect(await service.initialize(), isTrue);
        expect(opened, isEmpty);
      });

      test('scheduleAll puts the tab reminders back after clearing the '
          'schedule, even with the daily notifications off', () async {
        await service.scheduleAll(disabled);

        expect(order, ['cancel', 'tabs']);
      });

      test('a failing tab restore still schedules the daily '
          'notifications', () async {
        service = build(rescheduleTabReminders: () async => throw 'boom');

        await service.scheduleAll(
          const AppSettings(
            notifications: NotificationSettings(
              notificationsEnabled: true,
              morningReminderEnabled: true,
              eveningSummaryEnabled: false,
            ),
          ),
        );

        verify(
          mockPlugin.zonedSchedule(
            NotificationService.morningReminderId,
            any,
            any,
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).called(1);
      });

      // The plugin keeps only the handler of the latest initialize call
      // (the stub above stores it the same way), so the bill reminders must
      // pass the same one or a later bill write silently stops reminder taps.
      group('the bill reminders initialise with the same handler', () {
        late BillReminderService billReminders;

        setUp(() {
          billReminders = BillReminderService(
            plugin: mockPlugin,
            repository: SafeSpendFakeBillRepository(),
            onNotificationResponse: (response) =>
                service.handleNotificationResponse(response),
          );
          service = build(rescheduleBillReminders: billReminders.rescheduleAll);
        });

        test('a pay later tap still routes after a re-schedule '
            'initialised the bill reminders', () async {
          await service.scheduleAll(disabled);

          handler!(tap('pay_later:t1'));
          expect(opened, ['t1']);
        });

        test('a pay later tap still routes when a bill write initialised '
            'the plugin last (no re-schedule since)', () async {
          await service.initialize();
          await billReminders.initialize();

          handler!(tap('pay_later:t1'));
          expect(opened, ['t1']);
        });

        test('no initialize call ever clears the handler', () async {
          final passed = <Object?>[];
          when(
            mockPlugin.initialize(
              any,
              onDidReceiveNotificationResponse: anyNamed(
                'onDidReceiveNotificationResponse',
              ),
            ),
          ).thenAnswer((invocation) async {
            passed.add(
              invocation.namedArguments[#onDidReceiveNotificationResponse],
            );
            return true;
          });

          await billReminders.initialize();
          await service.scheduleAll(disabled);

          expect(passed, isNotEmpty);
          expect(passed, everyElement(isNotNull));
        });

        test('a bill reminder tap behaves as before: nothing opens', () async {
          await service.initialize();
          await billReminders.initialize();

          // Bill reminders carry no payload.
          handler!(tap(null));
          handler!(tap(''));
          handler!(tap('daily_spending_limit'));

          expect(opened, isEmpty);
        });
      });
    });
  });
}

class FakeAndroidFlutterLocalNotificationsPlugin extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  int requestNotificationsPermissionCallCount = 0;

  /// What [areNotificationsEnabled] answers.
  bool enabled = true;

  @override
  Future<bool?> areNotificationsEnabled() async => enabled;

  @override
  Future<bool?> requestNotificationsPermission() async {
    requestNotificationsPermissionCallCount += 1;
    return true;
  }

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {}
}

class FakeIOSFlutterLocalNotificationsPlugin extends Fake
    implements IOSFlutterLocalNotificationsPlugin {
  int requestPermissionsCallCount = 0;

  @override
  Future<bool?> requestPermissions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
    bool critical = false,
    bool provisional = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requestPermissionsCallCount += 1;
    return true;
  }
}
