import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';

import 'package:monivo/features/settings/domain/services/notification_service.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin, BudgetRepository])
import 'notification_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NotificationService notificationService;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockBudgetRepository mockBudgetRepository;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockBudgetRepository = MockBudgetRepository();
    notificationService = NotificationService(
      plugin: mockPlugin,
      budgetRepository: mockBudgetRepository,
      calculationService: BudgetCalculationService(),
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
      });

      test(
        'should schedule enabled notifications with formatted amounts',
        () async {
          when(
            mockBudgetRepository.getActiveBudget(),
          ).thenAnswer((_) async => null);

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
          verify(
            mockPlugin.zonedSchedule(
              NotificationService.morningReminderId,
              'Good morning! 🌅',
              'Check your budget and plan your spending for today.',
              any,
              any,
              androidScheduleMode: anyNamed('androidScheduleMode'),
              matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
            ),
          ).called(1);
        },
      );

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
            'Good morning! 🌅',
            'Check your budget and plan your spending for today.',
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        );
      });

      test('should schedule the configured reminder time', () async {
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
            'Good morning! 🌅',
            'Check your budget and plan your spending for today.',
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
          ),
        ).called(1);
      });
    });

    group('cancelAll', () {
      test('should cancel all notifications', () async {
        when(mockPlugin.cancelAll()).thenAnswer((_) async => {});

        await notificationService.cancelAll();

        verify(mockPlugin.cancelAll()).called(1);
      });
    });

    group('cancel', () {
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
