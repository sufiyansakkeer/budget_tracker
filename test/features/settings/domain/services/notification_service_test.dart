import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';

import 'package:monivo/features/settings/domain/services/notification_service.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin, BudgetRepository])
import 'notification_service_test.mocks.dart';

class FakeGetSpendingTargetsUseCase implements GetSpendingTargetsUseCase {
  SpendingTargetEntity? targetsToReturn;

  FakeGetSpendingTargetsUseCase({this.targetsToReturn});

  @override
  final BudgetRepository repository = MockBudgetRepository();
  @override
  final BudgetCalculationService calculationService =
      BudgetCalculationService();

  @override
  Future<SpendingTargetResult> call({DateTime? referenceDate}) async {
    if (targetsToReturn != null) {
      return SpendingTargetSuccess(targetsToReturn!);
    }
    return const SpendingTargetNoBudget();
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
      targetsToReturn: const SpendingTargetEntity(
        dailyTarget: 1500,
        dailySpent: 500,
        dailyRemaining: 1000,
        dailyExceeded: 0,
        dailyProgress: 0.33,
        dailyStatus: SpendingTargetStatus.onTrack,
        weeklyTarget: 10500,
        weeklySpent: 3500,
        weeklyRemaining: 7000,
        weeklyExceeded: 0,
        weeklyProgress: 0.33,
        weeklyStatus: SpendingTargetStatus.onTrack,
        currency: 'INR',
      ),
    );
    notificationService = NotificationService(
      plugin: mockPlugin,
      budgetRepository: mockBudgetRepository,
      calculationService: BudgetCalculationService(),
      spendingTargetsUseCase: fakeSpendingTargetsUseCase,
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
          // Verify the morning notification has a dynamic body (not the old static text)
          verify(
            mockPlugin.zonedSchedule(
              NotificationService.morningReminderId,
              "Today's Spending Limit",
              argThat(contains('safely spend')),
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
        fakeSpendingTargetsUseCase.targetsToReturn = null;

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
            "Today's Spending Limit",
            'Check your budget and plan your spending for today.',
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
            "Today's Spending Limit",
            argThat(contains('safely spend')),
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).called(1);
      });
    });

    group('cancelAll', () {
      setUp(() {
        stubPluginInitialization();
      });

      test('should cancel all notifications', () async {
        when(mockPlugin.cancelAll()).thenAnswer((_) async => {});

        await notificationService.cancelAll();

        verify(mockPlugin.cancelAll()).called(1);
      });
    });

    group('cancel', () {
      setUp(() {
        stubPluginInitialization();
      });

      test('should cancel specific notification', () async {
        when(mockPlugin.cancel(any)).thenAnswer((_) async => {});

        await notificationService.cancel(1001);

        verify(mockPlugin.cancel(1001)).called(1);
      });
    });
  });
}

class FakeAndroidFlutterLocalNotificationsPlugin extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  int requestNotificationsPermissionCallCount = 0;

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
