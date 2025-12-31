import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler - HARUS top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

/// Service untuk mengelola Firebase Cloud Messaging
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  
  String? get fcmToken => _fcmToken;

  /// Initialize FCM - panggil setelah Firebase.initializeApp()
  Future<void> init() async {
    try {
      // Setup background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permission (untuk iOS/Android 13+)
      await _requestPermission();
      
      // Get FCM token
      await _getToken();
      
      // Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        _fcmToken = newToken;
        _saveTokenToDatabase(newToken);
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      debugPrint('[FCM] ✅ FCM Service initialized');
    } catch (e) {
      debugPrint('[FCM] ❌ Error initializing FCM: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  Future<void> _getToken() async {
    _fcmToken = await _messaging.getToken();
    debugPrint('[FCM] Token: $_fcmToken');
    
    if (_fcmToken != null) {
      await _saveTokenToDatabase(_fcmToken!);
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[FCM] No user logged in, skipping token save');
        return;
      }
      
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      
      debugPrint('[FCM] ✅ Token saved to database for user: $userId');
    } catch (e) {
      debugPrint('[FCM] ❌ Error saving token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message received:');
    debugPrint('[FCM] Title: ${message.notification?.title}');
    debugPrint('[FCM] Body: ${message.notification?.body}');
    debugPrint('[FCM] Data: ${message.data}');
    
    // Foreground messages sudah dihandle oleh flutter_local_notifications
    // via realtime subscription, jadi tidak perlu tampilkan lagi
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    
    // TODO: Navigate ke halaman yang sesuai berdasarkan message.data
    // Misalnya jika ada postId, navigate ke post detail
  }

  /// Call this when user logs in
  Future<void> onUserLogin() async {
    await _getToken();
  }

  /// Call this when user logs out
  Future<void> onUserLogout() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Clear token from database on logout
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', userId);
        debugPrint('[FCM] Token cleared from database');
      }
    } catch (e) {
      debugPrint('[FCM] Error clearing token: $e');
    }
  }
}
