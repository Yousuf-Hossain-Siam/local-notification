import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotifications {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static final onClickNotification = BehaviorSubject<String>();

  static void onNotificationTap(NotificationResponse notificationResponse) {
    onClickNotification.add(notificationResponse.payload!);
  }

  // Initialise the plugin. app_icon needs to be added as a drawable resource to the Android head project
  static const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  static final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();
  static final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(defaultActionName: 'Open notification');
  static final InitializationSettings initializationSettings =
      InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          linux: initializationSettingsLinux);

  // initialize the local notifications
  static Future init() async {
    // Request POST_NOTIFICATIONS permission for Android 13 (API 33) and above
    // This permission shows a standard runtime permission dialog.
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Request SCHEDULE_EXACT_ALARM permission for Android 12 (API 31) and above
    // This permission often directs the user to the app's system settings
    // where they must manually enable "Alarms & reminders" for the app.
    // It's crucial for `exactAllowWhileIdle` scheduling.
    if (await Permission.scheduleExactAlarm.isDenied) {
      // You might want to show a custom dialog here to explain to the user
      // why you need this permission before directing them to settings.
      // For example:
      /*
      await showDialog(
        context: navigatorKey.currentContext!, // Assuming you have access to context via a GlobalKey
        builder: (context) => AlertDialog(
          title: Text('Exact Alarms Permission'),
          content: Text('This app needs "Alarms & reminders" permission to send you timely notifications. Please enable it in settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings(); // Directs to app settings
              },
              child: Text('Open Settings'),
            ),
          ],
        ),
      );
      */
      await Permission.scheduleExactAlarm.request();
    }


    _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: onNotificationTap,
    );

    // Optional: After init, if exact alarm permission is still denied,
    // you might consider falling back to inexact alarms or notifying the user.
    if (await Permission.scheduleExactAlarm.isDenied) {
        print("Warning: Exact alarm permission was denied by the user. Scheduled notifications might not be exact.");
        // Consider changing androidScheduleMode to inexactAllowWhileIdle in showPeriodicNotifications
        // and showScheduleNotification if you don't absolutely need exact timing.
    }
  }

  // show a simple notification
  static Future showSimpleNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await _flutterLocalNotificationsPlugin
        .show(0, title, body, notificationDetails, payload: payload);
  }

  // to show periodic notification at regular interval
  static Future showPeriodicNotifications({
    required String title,
    required String body,
    required String payload,
  }) async {
    // Check if exact alarm permission is granted before scheduling
    // If not, you might want to inform the user or use inexact alarms
    if (await Permission.scheduleExactAlarm.isGranted) {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails('channel 2', 'your channel name',
              channelDescription: 'your channel description',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker');
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      await _flutterLocalNotificationsPlugin.periodicallyShow(
          1, title, body, RepeatInterval.everyMinute, notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload);
    } else {
      print("Exact alarm permission not granted. Cannot schedule exact periodic notification.");
      // Optionally fallback to inexact:
      /*
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails('channel 2', 'your channel name',
              channelDescription: 'your channel description',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker');
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      await _flutterLocalNotificationsPlugin.periodicallyShow(
          1, title, body, RepeatInterval.everyMinute, notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // Fallback
          payload: payload);
      */
    }
  }

  // to schedule a local notification
  static Future showScheduleNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    tz.initializeTimeZones();
    // Check if exact alarm permission is granted before scheduling
    if (await Permission.scheduleExactAlarm.isGranted) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
          2,
          title,
          body,
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
          const NotificationDetails(
              android: AndroidNotificationDetails(
                  'channel 3', 'your channel name',
                  channelDescription: 'your channel description',
                  importance: Importance.max,
                  priority: Priority.high,
                  ticker: 'ticker')),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload);
    } else {
      print("Exact alarm permission not granted. Cannot schedule exact notification.");
       // Optionally fallback to inexact:
      /*
      await _flutterLocalNotificationsPlugin.zonedSchedule(
          2,
          title,
          body,
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
          const NotificationDetails(
              android: AndroidNotificationDetails(
                  'channel 3', 'your channel name',
                  channelDescription: 'your channel description',
                  importance: Importance.max,
                  priority: Priority.high,
                  ticker: 'ticker')),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // Fallback
          payload: payload);
      */
    }
  }

  // close a specific channel notification
  static Future cancel(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // close all the notifications available
  static Future cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}