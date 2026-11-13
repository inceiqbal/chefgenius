import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service untuk mengelola local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    _isInitialized = true;
    debugPrint('✅ NotificationService: Initialized');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 NotificationService: Tapped - ${response.payload}');
    // Handle navigation based on payload if needed
  }

  /// Show notification when chatbot finishes generating response
  Future<void> showChatbotCompletedNotification({String? preview}) async {
    if (!_isInitialized) await init();

    final androidDetails = AndroidNotificationDetails(
      'chatbot_channel',
      'Chef Cei Chatbot',
      channelDescription: 'Notifikasi dari chatbot Chef Cei',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
      color: const Color(0xFFE67E22),
      styleInformation: const BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = preview != null && preview.length > 100
        ? '${preview.substring(0, 100)}...'
        : preview ?? 'Ketuk untuk melihat jawaban';

    await _notifications.show(
      100, // Notification ID for chatbot
      '🍳 Chef Cei sudah selesai menjawab!',
      body,
      details,
      payload: 'chatbot',
    );

    debugPrint('✅ NotificationService: Chatbot notification shown');
  }

  /// Cancel chatbot notification (when user opens chatbot screen)
  Future<void> cancelChatbotNotification() async {
    await _notifications.cancel(100);
  }
}
