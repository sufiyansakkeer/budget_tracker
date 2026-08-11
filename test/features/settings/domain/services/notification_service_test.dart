import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:budget_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:budget_tracker/features/settings/domain/entities/notification_settings.dart';
import 'package:budget_tracker/features/settings/domain/services/notification_service.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
import 'notification_service_test.mocks.dart';

void main() {
  late NotificationService notificationService;
  late MockFlutterLocalNotificationsPlugin mockPlugin;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    notificationService = NotificationService(plugin: mockPlugin);
  });

  group('NotificationService', () {
    group('initialize', () {
      test('should initialize successfully', () async {
        when(mockPlugin.initialize(any)).thenAnswer((_) async => true);

        final result = await notificationService.initialize();

        expect(result, true);
        expect(notificationService.isInitialized, true);
        verify(mockPlugin.initialize(any)).called(1);
      });

      test('should handle initialization failure', () async {
        when(mockPlugin.initialize(any)).thenAnswer((_) async => false);

        final result = await notificationService.initialize();

        expect(result, false);
        expect(notificationService.isInitialized, false);
      });
    });

    group('requestPermission', () {
      test('should return true on Android', () async {
        when(
          mockPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(null);
        when(mockPlugin.initialize(any)).thenAnswer((_) async => true);

        final result = await notificationService.requestPermission();

        expect(result, true);
      });

      test('should request permission on iOS', () async {
        final mockIOS = FakeIOSFlutterLocalNotificationsPlugin();
        when(
          mockPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(mockIOS);
        when(mockPlugin.initialize(any)).thenAnswer((_) async => true);

        final result = await notificationService.requestPermission();

        expect(result, true);
        expect(mockIOS.requestPermissionsCallCount, 1);
        expect(mockIOS.requestedAlert, true);
        expect(mockIOS.requestedBadge, true);
        expect(mockIOS.requestedSound, true);
      });
    });

    group('scheduleAll', () {
      test('should schedule all enabled notifications', () async {
        when(mockPlugin.initialize(any)).thenAnswer((_) async => true);
        when(
          mockPlugin.zonedSchedule(
            any,
            any,
            any,
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
            uiLocalNotificationDateInterpretation: anyNamed(
              'uiLocalNotificationDateInterpretation',
            ),
          ),
        ).thenAnswer((_) async {});

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

        verify(mockPlugin.cancelAll()).called(1);
        verify(
          mockPlugin.zonedSchedule(
            argThat(isA<int>()),
            argThat(isA<String>()),
            argThat(isA<String>()),
            argThat(isA<DateTime>()),
            argThat(isA<NotificationDetails>()),
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
            uiLocalNotificationDateInterpretation: anyNamed(
              'uiLocalNotificationDateInterpretation',
            ),
          ),
        ).called(greaterThan(0));
      });

      test('should not schedule when notifications disabled', () async {
        when(mockPlugin.initialize(any)).thenAnswer((_) async => true);

        final settings = AppSettings(
          notifications: const NotificationSettings(
            notificationsEnabled: false,
          ),
        );

        await notificationService.scheduleAll(settings);

        verify(mockPlugin.cancelAll()).called(1);
        verifyNever(
          mockPlugin.zonedSchedule(
            any,
            any,
            any,
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
            uiLocalNotificationDateInterpretation: anyNamed(
              'uiLocalNotificationDateInterpretation',
            ),
          ),
        );
      });

      test('should respect quiet hours', () async {
        when(mockPlugin.initialize(any)).thenAnswer((_) async => true);

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

        verify(mockPlugin.cancelAll()).called(1);
        // Morning reminder at 23:00 should be skipped due to quiet hours
        verifyNever(
          mockPlugin.zonedSchedule(
            any,
            any,
            any,
            any,
            any,
            androidScheduleMode: anyNamed('androidScheduleMode'),
            matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
            uiLocalNotificationDateInterpretation: anyNamed(
              'uiLocalNotificationDateInterpretation',
            ),
          ),
        );
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

// Fake for iOS-specific implementation. Mockito cannot safely stub this
// platform-interface method without a generated mock.
class FakeIOSFlutterLocalNotificationsPlugin extends Fake
    implements IOSFlutterLocalNotificationsPlugin {
  int requestPermissionsCallCount = 0;
  bool? requestedAlert;
  bool? requestedBadge;
  bool? requestedSound;

  @override
  Future<bool?> requestPermissions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
    bool critical = false,
    bool provisional = false,
  }) async {
    requestPermissionsCallCount += 1;
    requestedAlert = alert;
    requestedBadge = badge;
    requestedSound = sound;
    return true;
  }
}
